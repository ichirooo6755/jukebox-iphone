import Foundation
import JukeboxCore

enum GuestArtworkURL {
    static func imageURL(for item: QueueItem?, baseURL: String) -> URL? {
        guard let item else { return nil }
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return nil }

        if let artwork = item.artworkURL,
           let normalized = ArtworkURLNormalizer.normalize(artwork),
           let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: "\(trimmed)/api/artwork?url=\(encoded)")
        }

        var components = URLComponents(string: "\(trimmed)/api/artwork")
        components?.queryItems = [
            URLQueryItem(name: "service", value: item.service.rawValue),
            URLQueryItem(name: "music_id", value: item.musicID),
            URLQueryItem(name: "title", value: item.title),
            URLQueryItem(name: "artist", value: item.artist),
        ]
        return components?.url
    }

    static func imageURL(artworkURL: String?, service: MusicService, musicID: String, title: String, artist: String, baseURL: String) -> URL? {
        let item = QueueItem(
            id: 0,
            position: 0,
            title: title,
            artist: artist,
            artworkURL: artworkURL,
            service: service,
            musicID: musicID,
            duration: 0,
            addedBy: ""
        )
        return imageURL(for: item, baseURL: baseURL)
    }
}
