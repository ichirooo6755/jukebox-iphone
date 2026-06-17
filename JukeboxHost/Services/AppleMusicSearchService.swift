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
            message: authorized ? "Apple Musicログイン済み" : "ホストアプリでApple Musicを許可してください"
        )
    }

    func search(query: String) async -> [TrackSearchResult] {
        guard MusicAuthorization.currentStatus == .authorized else { return [] }

        var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
        request.limit = 20

        guard let response = try? await request.response() else { return [] }

        return response.songs.map { song in
            TrackSearchResult(
                title: song.title,
                artist: song.artistName,
                artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString,
                service: .appleMusic,
                musicID: song.id.rawValue,
                duration: Int(song.duration ?? 0)
            )
        }
    }

    func searchPlaylists(query: String) async -> [PlaylistSummary] {
        guard MusicAuthorization.currentStatus == .authorized else { return [] }

        var request = MusicCatalogSearchRequest(term: query, types: [Playlist.self])
        request.limit = 20

        guard let response = try? await request.response() else { return [] }

        return response.playlists.map { playlist in
            PlaylistSummary(
                id: playlist.id.rawValue,
                title: playlist.name,
                owner: playlist.curatorName ?? "Apple Music",
                artworkURL: playlist.artwork?.url(width: 300, height: 300)?.absoluteString,
                service: .appleMusic,
                trackCount: nil
            )
        }
    }

    func playlistTracks(playlistID: String, limit: Int) async -> [TrackSearchResult] {
        guard MusicAuthorization.currentStatus == .authorized else { return [] }

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
                artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString,
                service: .appleMusic,
                musicID: song.id.rawValue,
                duration: Int(song.duration ?? 0)
            )
        }
        .prefix(max(1, limit))
        .map { $0 }
    }
}
