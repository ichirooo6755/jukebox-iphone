import Foundation
import JukeboxCore
import MusicKit

struct AppleMusicSearchService: AppleMusicSearching {
    static func requestAuthorization() async -> Bool {
        let status = await MusicAuthorization.request()
        return status == .authorized
    }

    func authStatus() async -> ServiceAuthStatus {
        let authorized = MusicAuthorization.currentStatus == .authorized
        return ServiceAuthStatus(
            service: .appleMusic,
            isConfigured: true,
            isAuthenticated: authorized,
            loginURL: nil,
            message: authorized ? "ホストの MusicKit で再生（参加者は曲IDを送信）" : "ホストアプリで Apple Music を許可してください"
        )
    }

    func search(query: String) async -> [TrackSearchResult] {
        guard MusicAuthorization.currentStatus == .authorized else { return [] }

        async let catalogResults = searchCatalogSongs(query: query)
        async let libraryResults = searchLibrarySongs(query: query)
        return await dedupeTracks(catalogResults + libraryResults).prefix(20).map { $0 }
    }

    func unifiedSearch(query: String) async -> [UnifiedSearchResult] {
        guard MusicAuthorization.currentStatus == .authorized else { return [] }

        async let tracks = search(query: query)
        async let playlists = searchPlaylists(query: query)
        async let artists = searchArtists(query: query)

        let trackResults = await tracks.map {
            UnifiedSearchResult(
                id: $0.musicID,
                kind: .track,
                title: $0.title,
                subtitle: $0.artist,
                artworkURL: $0.artworkURL,
                service: .appleMusic,
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
                service: .appleMusic,
                trackCount: $0.trackCount
            )
        }
        let artistResults = await artists

        return (trackResults + playlistResults + artistResults).prefix(30).map { $0 }
    }

    private func searchCatalogSongs(query: String) async -> [TrackSearchResult] {
        var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
        request.limit = 15

        guard let response = try? await request.response() else { return [] }

        return response.songs.map { song in
            TrackSearchResult(
                title: song.title,
                artist: song.artistName,
                artworkURL: artworkURL(from: song.artwork),
                service: .appleMusic,
                musicID: song.id.rawValue,
                duration: Int(song.duration ?? 0)
            )
        }
    }

    private func searchLibrarySongs(query: String) async -> [TrackSearchResult] {
        var request = MusicLibrarySearchRequest(term: query, types: [Song.self])
        request.limit = 15

        guard let response = try? await request.response() else { return [] }

        return response.songs.map { song in
            TrackSearchResult(
                title: song.title,
                artist: song.artistName,
                artworkURL: artworkURL(from: song.artwork),
                service: .appleMusic,
                musicID: song.id.rawValue,
                duration: Int(song.duration ?? 0)
            )
        }
    }

    private func searchArtists(query: String) async -> [UnifiedSearchResult] {
        async let catalogArtists = searchCatalogArtists(query: query)
        async let libraryArtists = searchLibraryArtists(query: query)
        return await dedupeArtists(catalogArtists + libraryArtists).prefix(8).map { $0 }
    }

    private func searchCatalogArtists(query: String) async -> [UnifiedSearchResult] {
        var request = MusicCatalogSearchRequest(term: query, types: [Artist.self])
        request.limit = 8

        guard let response = try? await request.response() else { return [] }

        return response.artists.map { artist in
            UnifiedSearchResult(
                id: artist.id.rawValue,
                kind: .artist,
                title: artist.name,
                subtitle: "アーティスト",
                artworkURL: artworkURL(from: artist.artwork),
                service: .appleMusic,
                musicID: artist.id.rawValue
            )
        }
    }

    private func searchLibraryArtists(query: String) async -> [UnifiedSearchResult] {
        var request = MusicLibrarySearchRequest(term: query, types: [Artist.self])
        request.limit = 8

        guard let response = try? await request.response() else { return [] }

        return response.artists.map { artist in
            UnifiedSearchResult(
                id: artist.id.rawValue,
                kind: .artist,
                title: artist.name,
                subtitle: "アーティスト · マイライブラリ",
                artworkURL: artworkURL(from: artist.artwork),
                service: .appleMusic,
                musicID: artist.id.rawValue
            )
        }
    }

    func searchPlaylists(query: String) async -> [PlaylistSummary] {
        guard MusicAuthorization.currentStatus == .authorized else { return [] }

        async let catalogResults = searchCatalogPlaylists(query: query)
        async let libraryResults = searchLibraryPlaylists(query: query)
        return await dedupePlaylists(catalogResults + libraryResults).prefix(20).map { $0 }
    }

    private func searchCatalogPlaylists(query: String) async -> [PlaylistSummary] {
        var request = MusicCatalogSearchRequest(term: query, types: [Playlist.self])
        request.limit = 15

        guard let response = try? await request.response() else { return [] }

        return response.playlists.map { playlist in
            PlaylistSummary(
                id: playlist.id.rawValue,
                title: playlist.name,
                owner: playlist.curatorName ?? "Apple Music",
                artworkURL: artworkURL(from: playlist.artwork),
                service: .appleMusic,
                trackCount: nil
            )
        }
    }

    private func searchLibraryPlaylists(query: String) async -> [PlaylistSummary] {
        var request = MusicLibrarySearchRequest(term: query, types: [Playlist.self])
        request.limit = 15

        guard let response = try? await request.response() else { return [] }

        return response.playlists.map { playlist in
            PlaylistSummary(
                id: playlist.id.rawValue,
                title: playlist.name,
                owner: "マイライブラリ",
                artworkURL: artworkURL(from: playlist.artwork),
                service: .appleMusic,
                trackCount: nil
            )
        }
    }

    func artistTopTracks(artistID: String, limit: Int) async -> [TrackSearchResult] {
        guard MusicAuthorization.currentStatus == .authorized else { return [] }

        var request = MusicCatalogResourceRequest<Artist>(matching: \.id, equalTo: MusicItemID(artistID))
        request.properties = [.topSongs]

        guard let response = try? await request.response(),
              let artist = response.items.first,
              let songs = artist.topSongs else { return [] }

        return songs.prefix(max(1, limit)).map { song in
            TrackSearchResult(
                title: song.title,
                artist: song.artistName,
                artworkURL: artworkURL(from: song.artwork),
                service: .appleMusic,
                musicID: song.id.rawValue,
                duration: Int(song.duration ?? 0)
            )
        }
    }

    func playlistTracks(playlistID: String, limit: Int) async -> [TrackSearchResult] {
        guard MusicAuthorization.currentStatus == .authorized else { return [] }

        if let libraryTracks = await libraryPlaylistTracks(playlistID: playlistID, limit: limit), !libraryTracks.isEmpty {
            return libraryTracks
        }

        var request = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: MusicItemID(playlistID))
        request.properties = [.tracks]

        guard let response = try? await request.response(),
              let playlist = response.items.first,
              let tracks = playlist.tracks else { return [] }

        return tracks.compactMap { track in
            guard case .song(let song) = track else { return nil }
            return TrackSearchResult(
                title: song.title,
                artist: song.artistName,
                artworkURL: artworkURL(from: song.artwork),
                service: .appleMusic,
                musicID: song.id.rawValue,
                duration: Int(song.duration ?? 0)
            )
        }
        .prefix(max(1, limit))
        .map { $0 }
    }

    private func libraryPlaylistTracks(playlistID: String, limit: Int) async -> [TrackSearchResult]? {
        var request = MusicLibraryRequest<Playlist>()
        request.filter(matching: \.id, equalTo: MusicItemID(playlistID))

        guard let response = try? await request.response(),
              let playlist = response.items.first,
              let tracks = playlist.tracks else { return nil }

        return tracks.compactMap { track in
            guard case .song(let song) = track else { return nil }
            return TrackSearchResult(
                title: song.title,
                artist: song.artistName,
                artworkURL: artworkURL(from: song.artwork),
                service: .appleMusic,
                musicID: song.id.rawValue,
                duration: Int(song.duration ?? 0)
            )
        }
        .prefix(max(1, limit))
        .map { $0 }
    }

    private func artworkURL(from artwork: Artwork?) -> String? {
        guard let artwork else { return nil }
        for size in [600, 300, 120, 64] {
            guard let raw = artwork.url(width: size, height: size)?.absoluteString,
                  let normalized = ArtworkURLNormalizer.normalize(raw) else { continue }
            return normalized
        }
        return nil
    }

    private func dedupeTracks(_ tracks: [TrackSearchResult]) -> [TrackSearchResult] {
        var seen = Set<String>()
        return tracks.filter { track in
            let key = "\(track.title.lowercased())|\(track.artist.lowercased())"
            return seen.insert(key).inserted
        }
    }

    private func dedupePlaylists(_ playlists: [PlaylistSummary]) -> [PlaylistSummary] {
        var seen = Set<String>()
        return playlists.filter { playlist in
            let key = "\(playlist.title.lowercased())|\(playlist.owner.lowercased())"
            return seen.insert(key).inserted
        }
    }

    private func dedupeArtists(_ artists: [UnifiedSearchResult]) -> [UnifiedSearchResult] {
        var seen = Set<String>()
        return artists.filter { artist in
            seen.insert(artist.id).inserted
        }
    }
}
