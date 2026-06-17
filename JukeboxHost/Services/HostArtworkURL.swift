import Foundation
import JukeboxCore

enum HostArtworkURL {
    static func imageURL(for item: QueueItem?, port: UInt16 = JukeboxServer.defaultPort) -> URL? {
        guard let item else { return nil }

        if let raw = item.artworkURL,
           let normalized = ArtworkURLNormalizer.normalize(raw),
           let url = URL(string: normalized) {
            return url
        }

        var components = URLComponents()
        components.scheme = "http"
        components.host = JukeboxServer.localIPAddress() ?? "127.0.0.1"
        components.port = Int(port)
        components.path = "/api/artwork"
        components.queryItems = [
            URLQueryItem(name: "service", value: item.service.rawValue),
            URLQueryItem(name: "music_id", value: item.musicID),
            URLQueryItem(name: "title", value: item.title),
            URLQueryItem(name: "artist", value: item.artist),
        ]
        return components.url
    }
}
