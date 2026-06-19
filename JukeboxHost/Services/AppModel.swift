import Foundation
import JukeboxCore
import MusicKit
import Combine
import SwiftUI

enum HostDisplayMode: String, CaseIterable, Identifiable {
    case nowPlayingQueue
    case visualizer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nowPlayingQueue: return "再生＋キュー"
        case .visualizer: return "ビジュアライザ"
        }
    }

    var icon: String {
        switch self {
        case .nowPlayingQueue: return "music.note.list"
        case .visualizer: return "waveform"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    let store = JukeboxStore()
    let audioOutput = AudioOutputManager()
    #if os(iOS)
    let externalDisplay = ExternalDisplayManager()
    #endif

    @Published private(set) var server: JukeboxServer?
    @Published private(set) var serverStatus: HostServerStatus?
    @Published private(set) var playbackState = NowPlayingState.empty
    @Published private(set) var isServerRunning = false
    @Published private(set) var musicAuthorized = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var serviceAuthStatuses: [ServiceAuthStatus] = []
    @Published private(set) var displayedHostIP: String?
    @Published private(set) var remoteJoinCode: String?
    @Published private(set) var remoteJoinURL: String?
    @Published private(set) var remoteRelayConnected = false
    @Published var displayMode: HostDisplayMode = .nowPlayingQueue
    @Published private(set) var visualizerLevels: [CGFloat] = Array(repeating: 0.1, count: 32)
    @Published var crossfadeOpacity: Double = 1.0

    var participantURL: String? {
        participantJoinURL
    }

    /// QR 用の安定 URL（mDNS）。IP 変動の影響を受けにくい。
    var participantJoinURL: String? {
        let port = serverStatus?.port ?? Int(JukeboxServer.defaultPort)
        return "http://Jukebox.local:\(port)"
    }

    /// LAN IP 直アクセス用（フォールバック表示）
    var participantLocalURL: String? {
        let ip = displayedHostIP ?? serverStatus?.hostIP ?? JukeboxServer.localIPAddress()
        guard let ip else { return nil }
        let port = serverStatus?.port ?? Int(JukeboxServer.defaultPort)
        return "http://\(ip):\(port)"
    }

    private let playbackEngine = PlaybackEngine()
    private let lifecycle = HostLifecycleManager()
    private var progressTask: Task<Void, Never>?
    private var visualizerTask: Task<Void, Never>?
    private var subscriptionID: UUID?
    private let resolvedWebRoot: URL?
    private let remoteRelay = RemoteRelayClient()

    private var webRoot: URL? { resolvedWebRoot }

    private static func resolveWebRoot() -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []

        #if DEBUG
        let sourceFile = URL(fileURLWithPath: #filePath)
        let repoRoot = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        candidates.append(repoRoot.appendingPathComponent("web"))
        #endif

        candidates.append(contentsOf: [
            Bundle.main.resourceURL?.appendingPathComponent("web"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/web"),
        ].compactMap { $0 })

        for root in candidates {
            let index = root.appendingPathComponent("index.html")
            guard fm.isReadableFile(atPath: index.path),
                  let data = try? Data(contentsOf: index),
                  !data.isEmpty else { continue }
            return root
        }
        return nil
    }

    init() {
        resolvedWebRoot = Self.resolveWebRoot()
        Task { await bootstrap() }
    }

    private func bootstrap() async {
        audioOutput.configureSession()
        await SearchCoordinator.shared.setAppleMusicSearcher(AppleMusicSearchService())
        await ArtworkResolverRegistry.shared.setHandler { request in
            switch request.service {
            case .appleMusic:
                return await AppleMusicArtworkResolver.resolveImageData(
                    musicID: request.musicID,
                    title: request.title,
                    artist: request.artist
                )
            case .spotify, .youtube:
                return nil
            }
        }
        await store.setPlaybackController(playbackEngine)
        playbackEngine.onTrackFinished = { [weak self] in
            Task { try? await self?.store.onTrackFinished() }
        }
        playbackEngine.onLevelsUpdate = { [weak self] levels in
            Task { @MainActor in self?.visualizerLevels = levels }
        }

        subscriptionID = await store.subscribe { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                if case .state(let state) = event {
                    self.playbackState = state
                }
            }
        }

        musicAuthorized = await AppleMusicSearchService.requestAuthorization()
        await refreshAuthStatuses()
        playbackState = await store.currentState()
        #if os(iOS)
        externalDisplay.attach(model: self)
        externalDisplay.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        #endif
        await startHostServer()
    }

    private var cancellables = Set<AnyCancellable>()

    func startHostServer() async {
        guard !isServerRunning else { return }

        guard let webRoot else {
            errorMessage = "参加者用 Web UI が見つかりません。アプリを再ビルドしてから再度お試しください。"
            return
        }

        let jukeboxServer = JukeboxServer(store: store, webRoot: webRoot)
        server = jukeboxServer

        do {
            try await jukeboxServer.start()
            isServerRunning = true
            await refreshStatus()
            await refreshAuthStatuses()
            try await store.restoreSession()
            startProgressPolling()
            startVisualizer()
            lifecycle.start(
                onNetworkRestored: { [weak self] in await self?.handleNetworkRestored() },
                onServerRestartNeeded: { [weak self] in await self?.restartServerIfNeeded() }
            )
            await startRemoteRelayIfConfigured()
        } catch {
            errorMessage = "サーバー起動に失敗: \(error.localizedDescription)"
            isServerRunning = false
        }
    }

    func stopHostServer() async {
        remoteRelay.stop()
        remoteJoinCode = nil
        remoteJoinURL = nil
        remoteRelayConnected = false
        lifecycle.stop()
        progressTask?.cancel()
        visualizerTask?.cancel()
        progressTask = nil
        visualizerTask = nil
        #if os(iOS)
        externalDisplay.detach()
        #endif
        await server?.stop()
        server = nil
        isServerRunning = false
    }

    func refreshJoinAddress() async {
        displayedHostIP = JukeboxServer.localIPAddress()
        await refreshStatus()
        await refreshAuthStatuses()
    }

    private func handleNetworkRestored() async {
        await refreshJoinAddress()
        await restartServerIfNeeded()
        await startRemoteRelayIfConfigured()
    }

    func restartServerIfNeeded() async {
        guard isServerRunning else { return }
        if await isServerHealthy() { return }
        let wasPlaying = playbackState.isPlaying
        await server?.stop()
        let jukeboxServer = JukeboxServer(store: store, webRoot: webRoot)
        server = jukeboxServer
        do {
            try await jukeboxServer.start()
            await refreshStatus()
            await refreshAuthStatuses()
            if wasPlaying {
                try? await store.togglePlayback()
                try? await store.togglePlayback()
            }
        } catch {
            errorMessage = "サーバー再接続に失敗"
        }
    }

    func skip() async {
        await animateCrossfade()
        try? await store.skipTrack()
    }

    func togglePlayback() async {
        try? await store.togglePlayback()
    }

    private func refreshStatus() async {
        if displayedHostIP == nil {
            displayedHostIP = JukeboxServer.localIPAddress()
        }
        let ip = displayedHostIP ?? JukeboxServer.localIPAddress() ?? "127.0.0.1"
        let clients = await server?.clientCount ?? 0
        await store.setConnectedClients(clients)
        serverStatus = HostServerStatus(
            hostIP: ip,
            port: Int(JukeboxServer.defaultPort),
            connectedClients: clients,
            wifiConnected: JukeboxServer.localIPAddress() != nil
        )
        playbackState = await store.currentState()
        remoteJoinCode = remoteRelay.joinCode
        remoteJoinURL = remoteRelay.joinURL
        remoteRelayConnected = remoteRelay.isConnected
    }

    private func refreshAuthStatuses() async {
        let ip = displayedHostIP ?? JukeboxServer.localIPAddress() ?? "127.0.0.1"
        let baseURL = "http://\(ip):\(JukeboxServer.defaultPort)"
        serviceAuthStatuses = await SearchCoordinator.shared.authStatuses(baseURL: baseURL)
    }

    private func startProgressPolling() {
        progressTask?.cancel()
        progressTask = Task {
            while !Task.isCancelled {
                await store.updateProgress()
                if Int(Date().timeIntervalSince1970) % 10 == 0 {
                    await refreshStatus()
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func startVisualizer() {
        visualizerTask?.cancel()
        visualizerTask = Task {
            while !Task.isCancelled {
                if !playbackState.isPlaying {
                    visualizerLevels = visualizerLevels.map { max(0.05, $0 * 0.9) }
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
    }

    private func animateCrossfade() async {
        withAnimation(.easeOut(duration: 0.35)) { crossfadeOpacity = 0.3 }
        try? await Task.sleep(nanoseconds: 350_000_000)
        withAnimation(.easeIn(duration: 0.35)) { crossfadeOpacity = 1.0 }
    }

    private func isServerHealthy() async -> Bool {
        let ip = JukeboxServer.localIPAddress() ?? "127.0.0.1"
        let port = serverStatus?.port ?? Int(JukeboxServer.defaultPort)
        guard let url = URL(string: "http://\(ip):\(port)/api/health") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              String(data: data, encoding: .utf8) == "ok" else {
            return false
        }
        return true
    }

    private func startRemoteRelayIfConfigured() async {
        guard let relayURL = RemoteRelayClient.relayBaseURLFromEnvironment() else { return }
        remoteRelay.configure { [weak self] in
            guard let self else { return NowPlayingState.empty }
            return await self.store.currentState()
        }
        await remoteRelay.start(relayBaseURL: relayURL, localPort: JukeboxServer.defaultPort)
        remoteJoinCode = remoteRelay.joinCode
        remoteJoinURL = remoteRelay.joinURL
        remoteRelayConnected = remoteRelay.isConnected
        if let error = remoteRelay.lastError {
            errorMessage = "リモート参加: \(error)"
        }
    }
}
