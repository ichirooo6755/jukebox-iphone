import Foundation

public protocol AppleMusicSearching: Sendable {
    func authStatus() async -> ServiceAuthStatus
    func search(query: String) async -> [TrackSearchResult]
    func searchPlaylists(query: String) async -> [PlaylistSummary]
    func playlistTracks(playlistID: String, limit: Int) async -> [TrackSearchResult]
}

public actor SearchCoordinator {
    public static let shared = SearchCoordinator()

    private var appleMusicSearcher: (any AppleMusicSearching)?

    public func setAppleMusicSearcher(_ searcher: (any AppleMusicSearching)?) {
        appleMusicSearcher = searcher
    }

    public func search(query: String, service: MusicService) async -> [TrackSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        switch service {
        case .appleMusic:
            return await appleMusicSearcher?.search(query: trimmed) ?? []
        case .spotify:
            return await SpotifySearchService.shared.search(query: trimmed)
        case .youtube:
            return await YouTubeSearchService.shared.search(query: trimmed)
        }
    }

    public func authStatuses(baseURL: String) async -> [ServiceAuthStatus] {
        [
            await appleMusicSearcher?.authStatus() ?? ServiceAuthStatus(
                service: .appleMusic,
                isConfigured: false,
                isAuthenticated: false,
                loginURL: nil,
                message: "ホストアプリでApple Musicの許可が必要です"
            ),
            await SpotifySearchService.shared.authStatus(baseURL: baseURL),
            await YouTubeSearchService.shared.authStatus(baseURL: baseURL)
        ]
    }

    public func beginAuth(service: MusicService, baseURL: String) async -> URL? {
        switch service {
        case .appleMusic:
            return nil
        case .spotify:
            return await SpotifySearchService.shared.beginAuthorization(baseURL: baseURL)
        case .youtube:
            return await YouTubeSearchService.shared.beginAuthorization(baseURL: baseURL)
        }
    }

    public func completeAuth(service: MusicService, code: String, state: String, baseURL: String) async -> Bool {
        switch service {
        case .appleMusic:
            return false
        case .spotify:
            return await SpotifySearchService.shared.completeAuthorization(code: code, state: state, baseURL: baseURL)
        case .youtube:
            return await YouTubeSearchService.shared.completeAuthorization(code: code, state: state, baseURL: baseURL)
        }
    }

    public func searchPlaylists(query: String, service: MusicService) async -> [PlaylistSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        switch service {
        case .appleMusic:
            return await appleMusicSearcher?.searchPlaylists(query: trimmed) ?? []
        case .spotify:
            return await SpotifySearchService.shared.searchPlaylists(query: trimmed)
        case .youtube:
            return await YouTubeSearchService.shared.searchPlaylists(query: trimmed)
        }
    }

    public func playlistTracks(service: MusicService, playlistID: String, limit: Int) async -> [TrackSearchResult] {
        switch service {
        case .appleMusic:
            return await appleMusicSearcher?.playlistTracks(playlistID: playlistID, limit: limit) ?? []
        case .spotify:
            return await SpotifySearchService.shared.playlistTracks(playlistID: playlistID, limit: limit)
        case .youtube:
            return await YouTubeSearchService.shared.playlistTracks(playlistID: playlistID, limit: limit)
        }
    }
}
