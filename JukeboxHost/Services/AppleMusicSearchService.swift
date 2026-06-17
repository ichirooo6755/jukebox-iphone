import Foundation
import JukeboxCore
import MusicKit

struct AppleMusicSearchService: AppleMusicSearching {
    static func requestAuthorization() async -> Bool {
        let status = await MusicAuthorization.request()
        return status == .authorized
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
}
