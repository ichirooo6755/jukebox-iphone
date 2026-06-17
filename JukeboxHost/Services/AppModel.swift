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

    @Published private(set) var server: JukeboxServer?
    @Published private(set) var serverStatus: HostServerStatus?
    @Published private(set) var playbackState = NowPlayingState.empty
    @Published private(set) var isServerRunning = false
    @Published private(set) var musicAuthorized = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var serviceAuthStatuses: [ServiceAuthStatus] = []
    @Published var displayMode: HostDisplayMode = .nowPlayingQueue
    @Published private(set) var visualizerLevels: [CGFloat] = Array(repeating: 0.1, count: 32)
    @Published var crossfadeOpacity: Double = 1.0

    var participantURL: String? {
        guard let local = participantLocalURL else { return nil }
        return "\(local)?join=1"
    }

    var participantLocalURL: String? {
        let ip = serverStatus?.hostIP ?? JukeboxServer.localIPAddress()
        guard let ip else { return nil }
        let port = serverStatus?.port ?? Int(JukeboxServer.defaultPort)
        return "http://\(ip):\(port)"
    }

    private let playbackEngine = PlaybackEngine()
    private let lifecycle = HostLifecycleManager()
    private var progressTask: Task<Void, Never>?
    private var visualizerTask: Task<Void, Never>?
    private var subscriptionID: UUID?
    private var webRoot: URL? {
        Self.resolveWebRoot()
    }

    private static func resolveWebRoot() -> URL? {
        let fm = FileManager.default
        let candidates: [URL] = [
            Bundle.main.resourceURL?.appendingPathComponent("web"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/web"),
        ].compactMap { $0 } + developmentWebRootCandidates()

        for root in candidates {
            let index = root.appendingPathComponent("index.html")
            if fm.fileExists(atPath: index.path) {
                return root
            }
        }
        return nil
    }

    private static func developmentWebRootCandidates() -> [URL] {
        #if DEBUG
        let sourceFile = URL(fileURLWithPath: #filePath)
        let repoRoot = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return [repoRoot.appendingPathComponent("web")]
        #else
        return []
        #endif
    }

    init() {
        Task { await bootstrap() }
    }

    private func bootstrap() async {
        audioOutput.configureSession()
        await SearchCoordinator.shared.setAppleMusicSearcher(AppleMusicSearchService())
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
        await startHostServer()
    }

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
                onNetworkRestored: { [weak self] in await self?.restartServerIfNeeded() },
                onServerRestartNeeded: { [weak self] in await self?.restartServerIfNeeded() }
            )
        } catch {
            errorMessage = "サーバー起動に失敗: \(error.localizedDescription)"
            isServerRunning = false
        }
    }

    func stopHostServer() async {
        lifecycle.stop()
        progressTask?.cancel()
        visualizerTask?.cancel()
        progressTask = nil
        visualizerTask = nil
        await server?.stop()
        server = nil
        isServerRunning = false
    }

    func restartServerIfNeeded() async {
        guard isServerRunning else { return }
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

    func cycleDisplayMode() {
        let modes = HostDisplayMode.allCases
        guard let idx = modes.firstIndex(of: displayMode) else { return }
        displayMode = modes[(idx + 1) % modes.count]
    }

    private func refreshStatus() async {
        let ip = JukeboxServer.localIPAddress() ?? "127.0.0.1"
        let clients = await server?.clientCount ?? 0
        await store.setConnectedClients(clients)
        serverStatus = HostServerStatus(
            hostIP: ip,
            port: Int(JukeboxServer.defaultPort),
            connectedClients: clients,
            wifiConnected: JukeboxServer.localIPAddress() != nil
        )
        playbackState = await store.currentState()
    }

    private func refreshAuthStatuses() async {
        let ip = JukeboxServer.localIPAddress() ?? "127.0.0.1"
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
}
