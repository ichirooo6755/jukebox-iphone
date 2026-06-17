import Foundation
import JukeboxCore
import MusicKit

@MainActor
final class GuestAppleMusicService: ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var displayName: String?

    func refreshAuthorization() {
        isAuthorized = MusicAuthorization.currentStatus == .authorized
    }

    func requestAuthorization() async -> Bool {
        let status = await MusicAuthorization.request()
        isAuthorized = status == .authorized
        return isAuthorized
    }

    func myPlaylists() async -> [PlaylistSummary] {
        guard MusicAuthorization.currentStatus == .authorized else { return [] }

        var request = MusicLibraryRequest<Playlist>()
        request.limit = 50
        guard let response = try? await request.response() else { return [] }

        return response.items.map { playlist in
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

    func playlistTracks(playlistID: String, limit: Int = 50) async -> [PlaylistLaneTrack] {
        guard MusicAuthorization.currentStatus == .authorized else { return [] }

        var request = MusicLibraryRequest<Playlist>()
        request.filter(matching: \.id, equalTo: MusicItemID(playlistID))
        guard let response = try? await request.response(),
              let playlist = response.items.first,
              let tracks = playlist.tracks else { return [] }

        var results: [PlaylistLaneTrack] = []
        for track in tracks {
            guard case .song(let song) = track else { continue }
            results.append(PlaylistLaneTrack(
                title: song.title,
                artist: song.artistName,
                artworkURL: artworkURL(from: song.artwork),
                service: .appleMusic,
                musicID: song.id.rawValue,
                duration: Int(song.duration ?? 0)
            ))
            if results.count >= max(1, limit) { break }
        }
        return results
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
}
