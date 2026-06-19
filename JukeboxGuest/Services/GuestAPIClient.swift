import Foundation
import JukeboxCore

struct DiscoverHostInfo: Codable, Identifiable, Sendable {
    var id: String { url }
    var url: String
    var name: String?
    var hostIP: String?

    enum CodingKeys: String, CodingKey {
        case url, name
        case hostIP = "host_ip"
    }
}

struct SyncMetrics: Codable, Sendable {
    var roundTripMs: Double?
    var connectedClients: Int?
    var broadcastCount: Int?

    enum CodingKeys: String, CodingKey {
        case roundTripMs = "round_trip_ms"
        case connectedClients = "connected_clients"
        case broadcastCount = "broadcast_count"
    }
}

@MainActor
final class GuestAPIClient: ObservableObject {
    @Published var hostURL: String {
        didSet {
            UserDefaults.standard.set(hostURL, forKey: "jukebox_guest_host")
            reconnectTransport()
        }
    }
    @Published var nickname: String {
        didSet { UserDefaults.standard.set(nickname, forKey: "jukebox_guest_nickname") }
    }
    @Published var playbackState = NowPlayingState.empty
    @Published var authStatuses: [ServiceAuthStatus] = []
    @Published var errorMessage: String?
    @Published var toastMessage: String?
    @Published private(set) var isConnected = false
    @Published private(set) var discoveredHosts: [DiscoverHostInfo] = []
    @Published private(set) var syncMetrics: SyncMetrics?
    @Published var showOnboarding = false

    let webSocket = GuestWebSocketClient()

    private var statePollTask: Task<Void, Never>?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        hostURL = UserDefaults.standard.string(forKey: "jukebox_guest_host") ?? ""
        nickname = UserDefaults.standard.string(forKey: "jukebox_guest_nickname") ?? ""
        showOnboarding = nickname.isEmpty && hostURL.isEmpty

        webSocket.onEvent = { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        webSocket.onConnectionChange = { [weak self] online in
            Task { @MainActor in
                self?.isConnected = online
                if online {
                    await self?.refreshState()
                }
            }
        }
    }

    private var baseURL: String { hostURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }

    private func participantQuery() -> String {
        guard !nickname.isEmpty else { return "" }
        let encoded = nickname.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? nickname
        return "?participant=\(encoded)"
    }

    private func withParticipant(_ path: String) -> String {
        guard !nickname.isEmpty else { return path }
        let encoded = nickname.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? nickname
        let joiner = path.contains("?") ? "&" : "?"
        return "\(path)\(joiner)participant=\(encoded)"
    }

    func connectToHost(_ url: String) async {
        hostURL = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        showOnboarding = false
        do {
            try await ensureParticipant()
            await refreshState()
            await refreshAuth()
            reconnectTransport()
            startStatePolling()
            showToast("ホストに接続しました")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reconnectTransport() {
        guard !baseURL.isEmpty else {
            webSocket.disconnect()
            isConnected = false
            stopStatePolling()
            GuestLiveActivityManager.shared.end()
            return
        }
        webSocket.connect(baseURL: baseURL)
        startStatePolling()
    }

    private func startStatePolling() {
        statePollTask?.cancel()
        statePollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, !baseURL.isEmpty else { continue }
                await refreshState()
            }
        }
    }

    private func stopStatePolling() {
        statePollTask?.cancel()
        statePollTask = nil
    }

    private func handle(_ event: JukeboxEvent) {
        switch event {
        case .state(let state):
            playbackState = state
            GuestLiveActivityManager.shared.sync(state: state, hostURL: baseURL, nickname: nickname)
        case .queueUpdated(let queue):
            playbackState.queue = queue
        }
    }

    func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    private func request(path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    func ensureParticipant() async throws {
        guard nickname.isEmpty else { return }
        let body = try JSONEncoder().encode(NicknameRequest(nickname: ""))
        let data = try await request(path: "/api/users", method: "POST", body: body)
        let user = try decoder.decode(UserProfile.self, from: data)
        nickname = user.nickname
        showOnboarding = false
    }

    func registerNickname(_ name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = try JSONEncoder().encode(NicknameRequest(nickname: trimmed))
        let data = try await request(path: "/api/users", method: "POST", body: body)
        let user = try decoder.decode(UserProfile.self, from: data)
        nickname = user.nickname
        showOnboarding = false
        await refreshAuth()
    }

    func refreshState() async {
        guard !baseURL.isEmpty else { return }
        do {
            let data = try await request(path: "/api/state")
            playbackState = try decoder.decode(NowPlayingState.self, from: data)
            GuestLiveActivityManager.shared.sync(state: playbackState, hostURL: baseURL, nickname: nickname)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshAuth() async {
        guard !baseURL.isEmpty else { return }
        do {
            try await ensureParticipant()
            let data = try await request(path: "/api/auth/status\(participantQuery())")
            authStatuses = try decoder.decode([ServiceAuthStatus].self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshMetrics() async {
        guard !baseURL.isEmpty else { return }
        let started = Date()
        do {
            _ = try await request(path: "/api/state")
            let roundTrip = Date().timeIntervalSince(started) * 1000
            let data = try await request(path: "/api/metrics")
            var metrics = try decoder.decode(SyncMetrics.self, from: data)
            metrics.roundTripMs = roundTrip
            syncMetrics = metrics
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func discoverHosts() async {
        let port = 8765
        var candidates = Set<String>()
        if !baseURL.isEmpty { candidates.insert(baseURL) }
        candidates.insert("http://Jukebox.local:\(port)")
        candidates.insert("http://jukebox.local:\(port)")

        var found: [DiscoverHostInfo] = []
        await withTaskGroup(of: DiscoverHostInfo?.self) { group in
            for base in candidates {
                group.addTask { await self.discoverAt(base) }
            }
            for await item in group {
                if let item { found.append(item) }
            }
        }

        var unique: [DiscoverHostInfo] = []
        var seen = Set<String>()
        for item in found {
            guard !seen.contains(item.url) else { continue }
            seen.insert(item.url)
            unique.append(item)
        }
        discoveredHosts = unique
    }

    private func discoverAt(_ base: String) async -> DiscoverHostInfo? {
        let trimmed = base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/api/discover") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let info = try? decoder.decode(DiscoverHostInfo.self, from: data) else {
            return nil
        }
        return info
    }

    func setPlaybackMode(_ mode: QueuePlaybackMode) async {
        do {
            let body = try JSONEncoder().encode(PlaybackModeRequest(mode: mode))
            let data = try await request(path: "/api/playback-mode", method: "PUT", body: body)
            let state = try decoder.decode(PlaylistRouletteState.self, from: data)
            playbackState.playbackMode = state.mode
            playbackState.playlistLanes = state.lanes
            playbackState.sessionStartedAt = state.sessionStartedAt
            showToast("再生モードを変更しました")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePlayback() async {
        do {
            _ = try await request(path: "/api/playback/toggle", method: "POST")
            await refreshState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func skipTrack() async {
        do {
            _ = try await request(path: "/api/playback/skip", method: "POST")
            await refreshState()
            showToast("スキップしました")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func voteSkip() async {
        do {
            try await ensureParticipant()
            let body = try JSONEncoder().encode(SkipVoteRequest(nickname: nickname))
            _ = try await request(path: "/api/playback/vote-skip", method: "POST", body: body)
            await refreshState()
            showToast("スキップに投票しました")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func searchTracks(query: String, service: MusicService) async throws -> [TrackSearchResult] {
        try await ensureParticipant()
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let data = try await request(path: withParticipant("/api/search?q=\(encoded)&service=\(service.rawValue)"))
        return try decoder.decode([TrackSearchResult].self, from: data)
    }

    func unifiedSearch(query: String) async throws -> [UnifiedSearchResult] {
        try await ensureParticipant()
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let data = try await request(path: withParticipant("/api/search/unified?q=\(encoded)&service=apple_music"))
        return try decoder.decode([UnifiedSearchResult].self, from: data)
    }

    func importArtist(service: MusicService, artistID: String, limit: Int = 5) async throws {
        try await ensureParticipant()
        let body = try JSONEncoder().encode(ArtistImportRequest(
            service: service,
            artistID: artistID,
            addedBy: nickname,
            limit: limit
        ))
        _ = try await request(path: "/api/artists/import", method: "POST", body: body)
        await refreshState()
        showToast("アーティストの曲を追加しました")
    }

    func addToQueue(track: TrackSearchResult) async throws {
        try await ensureParticipant()
        let body = try JSONEncoder().encode(QueueItemInput(
            title: track.title,
            artist: track.artist,
            artworkURL: track.artworkURL,
            service: track.service,
            musicID: track.musicID,
            duration: track.duration,
            addedBy: nickname
        ))
        _ = try await request(path: "/api/queue", method: "POST", body: body)
        await refreshState()
        showToast("キューに追加しました")
    }

    func removeFromQueue(id: Int) async throws {
        _ = try await request(path: "/api/queue/\(id)", method: "DELETE")
        await refreshState()
    }

    func reorderQueue(order: [Int]) async throws {
        let body = try JSONEncoder().encode(ReorderRequest(order: order))
        _ = try await request(path: "/api/queue/reorder", method: "PUT", body: body)
        await refreshState()
    }

    func importPlaylistURL(_ urlString: String) async throws {
        try await ensureParticipant()
        await refreshAuth()
        let resolveBody = try JSONEncoder().encode(PlaylistURLResolveRequest(url: urlString))
        let summaryData = try await request(
            path: "/api/playlists/resolve-url\(participantQuery())",
            method: "POST",
            body: resolveBody
        )
        let summary = try decoder.decode(PlaylistSummary.self, from: summaryData)
        try await importPlaylistSummary(summary)
    }

    func myPlaylists(service: MusicService) async throws -> [PlaylistSummary] {
        try await ensureParticipant()
        let data = try await request(path: withParticipant("/api/playlists/mine?service=\(service.rawValue)"))
        return try decoder.decode([PlaylistSummary].self, from: data)
    }

    func searchPlaylists(service: MusicService, query: String) async throws -> [PlaylistSummary] {
        try await ensureParticipant()
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let data = try await request(path: withParticipant("/api/playlists?q=\(encoded)&service=\(service.rawValue)"))
        return try decoder.decode([PlaylistSummary].self, from: data)
    }

    func importPlaylistSummary(_ summary: PlaylistSummary) async throws {
        try await ensureParticipant()
        await refreshAuth()
        let profile = authStatuses.first(where: { $0.service == summary.service })
        if playbackState.playbackMode == .playlistRoulette {
            let importBody = try JSONEncoder().encode(PlaylistLaneImportRequest(
                service: summary.service,
                playlistID: summary.id,
                addedBy: nickname,
                limit: 50,
                displayName: profile?.displayName,
                avatarURL: profile?.avatarURL,
                playlistTitle: summary.title,
                playlistArtworkURL: summary.artworkURL
            ))
            _ = try await request(path: "/api/playlist-lanes", method: "POST", body: importBody)
        } else {
            let importBody = try JSONEncoder().encode(PlaylistImportRequest(
                service: summary.service,
                playlistID: summary.id,
                addedBy: nickname,
                limit: 50
            ))
            _ = try await request(path: "/api/playlists/import", method: "POST", body: importBody)
        }
        await refreshState()
        showToast("プレイリストを追加しました")
    }

    func importPlaylistTracks(
        service: MusicService,
        playlistTitle: String,
        playlistID: String?,
        playlistArtworkURL: String?,
        tracks: [PlaylistLaneTrack]
    ) async throws {
        try await ensureParticipant()
        let profile = authStatuses.first(where: { $0.service == service })
        let body = try JSONEncoder().encode(PlaylistTracksImportRequest(
            service: service,
            addedBy: nickname,
            playlistTitle: playlistTitle,
            tracks: tracks,
            displayName: profile?.displayName ?? nickname,
            avatarURL: profile?.avatarURL,
            playlistID: playlistID,
            playlistArtworkURL: playlistArtworkURL
        ))
        _ = try await request(path: "/api/playlists/import-tracks", method: "POST", body: body)
        await refreshState()
        showToast("プレイリストを追加しました")
    }

    func login(service: MusicService) async {
        guard let status = authStatuses.first(where: { $0.service == service }),
              let loginURL = status.loginURL,
              let url = authURL(loginURL) else {
            errorMessage = "ログイン URL を取得できません"
            return
        }
        do {
            let ok = try await GuestOAuthSession.shared.start(loginURL: url)
            if ok {
                await refreshAuth()
                showToast("\(service.displayName) にログインしました")
            } else {
                errorMessage = "\(service.displayName) のログインに失敗しました"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func authURL(_ loginPath: String, returnTo: String = "guest") -> URL? {
        let trimmed = loginPath.hasPrefix("http") ? loginPath : "\(baseURL)\(loginPath)"
        guard var components = URLComponents(string: trimmed) else { return nil }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "return", value: returnTo))
        components.queryItems = items
        return components.url
    }
}
