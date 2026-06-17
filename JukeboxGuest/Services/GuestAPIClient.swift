import Foundation
import JukeboxCore

@MainActor
final class GuestAPIClient: ObservableObject {
    @Published var hostURL: String {
        didSet { UserDefaults.standard.set(hostURL, forKey: "jukebox_guest_host") }
    }
    @Published var nickname: String {
        didSet { UserDefaults.standard.set(nickname, forKey: "jukebox_guest_nickname") }
    }
    @Published var playbackState = NowPlayingState.empty
    @Published var authStatuses: [ServiceAuthStatus] = []
    @Published var errorMessage: String?

    init() {
        hostURL = UserDefaults.standard.string(forKey: "jukebox_guest_host") ?? ""
        nickname = UserDefaults.standard.string(forKey: "jukebox_guest_nickname") ?? ""
    }

    private var baseURL: String { hostURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }

    private func participantQuery() -> String {
        guard !nickname.isEmpty else { return "" }
        let encoded = nickname.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? nickname
        return "?participant=\(encoded)"
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
        let user = try JSONDecoder().decode(UserProfile.self, from: data)
        nickname = user.nickname
    }

    func refreshState() async {
        do {
            let data = try await request(path: "/api/state")
            playbackState = try JSONDecoder().decode(NowPlayingState.self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshAuth() async {
        do {
            try await ensureParticipant()
            let data = try await request(path: "/api/auth/status\(participantQuery())")
            authStatuses = try JSONDecoder().decode([ServiceAuthStatus].self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setPlaybackMode(_ mode: QueuePlaybackMode) async {
        do {
            let body = try JSONEncoder().encode(PlaybackModeRequest(mode: mode))
            let data = try await request(path: "/api/playback-mode", method: "PUT", body: body)
            let state = try JSONDecoder().decode(PlaylistRouletteState.self, from: data)
            playbackState.playbackMode = state.mode
            playbackState.playlistLanes = state.lanes
            playbackState.sessionStartedAt = state.sessionStartedAt
        } catch {
            errorMessage = error.localizedDescription
        }
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
        let summary = try JSONDecoder().decode(PlaylistSummary.self, from: summaryData)
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
    }

    func authURL(_ loginPath: String) -> URL? {
        let trimmed = loginPath.hasPrefix("http") ? loginPath : "\(baseURL)\(loginPath)"
        guard var components = URLComponents(string: trimmed) else { return nil }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "return", value: "account"))
        components.queryItems = items
        return components.url
    }
}
