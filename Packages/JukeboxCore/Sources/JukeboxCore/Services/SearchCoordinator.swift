import Foundation

public protocol AppleMusicSearching: Sendable {
    func authStatus() async -> ServiceAuthStatus
    func search(query: String) async -> [TrackSearchResult]
    func searchPlaylists(query: String) async -> [PlaylistSummary]
    func unifiedSearch(query: String) async -> [UnifiedSearchResult]
    func playlistTracks(playlistID: String, limit: Int) async -> [TrackSearchResult]
    func artistTopTracks(artistID: String, limit: Int) async -> [TrackSearchResult]
}

public actor SearchCoordinator {
    public static let shared = SearchCoordinator()

    private var appleMusicSearcher: (any AppleMusicSearching)?

    public func setAppleMusicSearcher(_ searcher: (any AppleMusicSearching)?) {
        appleMusicSearcher = searcher
    }

    public func search(query: String, service: MusicService, participant: String? = nil) async -> [TrackSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        switch service {
        case .appleMusic:
            return await appleMusicSearcher?.search(query: trimmed) ?? []
        case .spotify:
            return await SpotifySearchService.shared.search(query: trimmed, participant: participant)
        case .youtube:
            return await YouTubeSearchService.shared.search(query: trimmed, participant: participant)
        }
    }

    public func authStatuses(baseURL: String, participant: String? = nil) async -> [ServiceAuthStatus] {
        [
            await appleMusicSearcher?.authStatus() ?? ServiceAuthStatus(
                service: .appleMusic,
                isConfigured: false,
                isAuthenticated: false,
                loginURL: nil,
                message: "ホストの MusicKit で再生（参加者は曲IDを送信）"
            ),
            await SpotifySearchService.shared.authStatus(baseURL: baseURL, participant: participant),
            await YouTubeSearchService.shared.authStatus(baseURL: baseURL, participant: participant)
        ]
    }

    public func beginAuth(
        service: MusicService,
        baseURL: String,
        participant: String? = nil,
        returnTo: String? = nil
    ) async -> URL? {
        switch service {
        case .appleMusic:
            return nil
        case .spotify:
            return await SpotifySearchService.shared.beginAuthorization(
                baseURL: baseURL,
                participant: participant,
                returnTo: returnTo
            )
        case .youtube:
            return await YouTubeSearchService.shared.beginAuthorization(
                baseURL: baseURL,
                participant: participant,
                returnTo: returnTo
            )
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

    public func searchPlaylists(query: String, service: MusicService, participant: String? = nil) async -> [PlaylistSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || service == .spotify || service == .youtube else { return [] }

        switch service {
        case .appleMusic:
            guard !trimmed.isEmpty else { return [] }
            return await appleMusicSearcher?.searchPlaylists(query: trimmed) ?? []
        case .spotify:
            return await SpotifySearchService.shared.searchPlaylists(query: trimmed, participant: participant)
        case .youtube:
            return await YouTubeSearchService.shared.searchPlaylists(query: trimmed, participant: participant)
        }
    }

    public func myPlaylists(service: MusicService, participant: String? = nil) async -> [PlaylistSummary] {
        switch service {
        case .appleMusic:
            return []
        case .spotify:
            return await SpotifySearchService.shared.fetchMyPlaylists(participant: participant)
        case .youtube:
            return await YouTubeSearchService.shared.searchPlaylists(query: "", participant: participant)
        }
    }

    public func unifiedSearch(query: String, service: MusicService, participant: String? = nil) async -> [UnifiedSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        switch service {
        case .appleMusic:
            return await appleMusicSearcher?.unifiedSearch(query: trimmed) ?? []
        case .spotify, .youtube:
            async let tracks = search(query: trimmed, service: service, participant: participant)
            async let playlists = searchPlaylists(query: trimmed, service: service, participant: participant)
            let trackResults = await tracks.map {
                UnifiedSearchResult(
                    id: $0.musicID,
                    kind: .track,
                    title: $0.title,
                    subtitle: $0.artist,
                    artworkURL: $0.artworkURL,
                    service: $0.service,
                    musicID: $0.musicID,
                    duration: $0.duration
                )
            }
            let playlistResults = await playlists.map {
                UnifiedSearchResult(
                    id: $0.id,
                    kind: .playlist,
                    title: $0.title,
                    subtitle: $0.owner,
                    artworkURL: $0.artworkURL,
                    service: $0.service,
                    trackCount: $0.trackCount
                )
            }
            return trackResults + playlistResults
        }
    }

    public func artistTopTracks(
        service: MusicService,
        artistID: String,
        limit: Int,
        participant: String? = nil
    ) async -> [TrackSearchResult] {
        switch service {
        case .appleMusic:
            return await appleMusicSearcher?.artistTopTracks(artistID: artistID, limit: limit) ?? []
        case .spotify, .youtube:
            return []
        }
    }

    public func playlistTracks(
        service: MusicService,
        playlistID: String,
        limit: Int,
        participant: String? = nil
    ) async -> [TrackSearchResult] {
        switch service {
        case .appleMusic:
            return await appleMusicSearcher?.playlistTracks(playlistID: playlistID, limit: limit) ?? []
        case .spotify:
            return await SpotifySearchService.shared.playlistTracks(
                playlistID: playlistID,
                limit: limit,
                participant: participant
            )
        case .youtube:
            return await YouTubeSearchService.shared.playlistTracks(
                playlistID: playlistID,
                limit: limit,
                participant: participant
            )
        }
    }

    public func resolvePlaylistURL(_ raw: String, participant: String? = nil) async -> PlaylistSummary? {
        guard let parsed = PlaylistURLParser.parse(raw) else { return nil }
        switch parsed.service {
        case .appleMusic:
            let tracks = await appleMusicSearcher?.playlistTracks(playlistID: parsed.playlistID, limit: 1) ?? []
            guard !tracks.isEmpty else { return nil }
            return PlaylistSummary(
                id: parsed.playlistID,
                title: tracks.first?.title ?? "Apple Music Playlist",
                owner: "Apple Music",
                artworkURL: tracks.first?.artworkURL,
                service: .appleMusic,
                trackCount: nil
            )
        case .spotify:
            return await SpotifySearchService.shared.fetchPlaylist(
                playlistID: parsed.playlistID,
                participant: participant
            )
        case .youtube:
            return await YouTubeSearchService.shared.fetchPlaylist(
                playlistID: parsed.playlistID,
                participant: participant
            )
        }
    }
}
