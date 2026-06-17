import Foundation
import JukeboxCore
import MusicKit
import Observation

@MainActor
@Observable
final class AppModel {
    let store = JukeboxStore()
    private(set) var server: JukeboxServer?
    private(set) var serverStatus: HostServerStatus?
    private(set) var playbackState = NowPlayingState.empty
    private(set) var isServerRunning = false
    private(set) var musicAuthorized = false
    private(set) var errorMessage: String?

    private let playbackEngine = PlaybackEngine()
    private var progressTask: Task<Void, Never>?
    private var subscriptionID: UUID?

    init() {
        Task { await bootstrap() }
    }

    private func bootstrap() async {
        await SearchCoordinator.shared.setAppleMusicSearcher(AppleMusicSearchService())
        await store.setPlaybackController(playbackEngine)
        playbackEngine.onTrackFinished = { [weak self] in
            Task { try? await self?.store.onTrackFinished() }
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
        playbackState = await store.currentState()
    }

    func startHostServer() async {
        guard !isServerRunning else { return }

        let webRoot = Bundle.main.resourceURL?.appendingPathComponent("web")
        let jukeboxServer = JukeboxServer(store: store, webRoot: webRoot)
        server = jukeboxServer

        do {
            try await jukeboxServer.start()
            isServerRunning = true
            let ip = JukeboxServer.localIPAddress() ?? "127.0.0.1"
            serverStatus = HostServerStatus(
                hostIP: ip,
                port: Int(JukeboxServer.defaultPort),
                connectedClients: await jukeboxServer.clientCount,
                wifiConnected: JukeboxServer.localIPAddress() != nil
            )
            try await store.restoreSession()
            startProgressPolling()
        } catch {
            errorMessage = "サーバー起動に失敗: \(error.localizedDescription)"
            isServerRunning = false
        }
    }

    func stopHostServer() async {
        progressTask?.cancel()
        progressTask = nil
        await server?.stop()
        server = nil
        isServerRunning = false
    }

    func skip() async {
        try? await store.skipTrack()
    }

    func togglePlayback() async {
        try? await store.togglePlayback()
    }

    private func startProgressPolling() {
        progressTask?.cancel()
        progressTask = Task {
            while !Task.isCancelled {
                await store.updateProgress()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
}
