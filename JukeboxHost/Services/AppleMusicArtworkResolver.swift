import Foundation
import JukeboxCore
import MusicKit

enum AppleMusicArtworkResolver {
    static func resolveImageData(musicID: String, title: String?, artist: String?) async -> Data? {
        if let url = await resolveHTTPSURL(musicID: musicID),
           let data = try? await fetchImageData(from: url) {
            return data
        }
        return await iTunesFallback(title: title, artist: artist)
    }

    static func resolveHTTPSURL(musicID: String) async -> String? {
        let itemID = MusicItemID(musicID)

        if let song = try? await MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: itemID).response().items.first,
           let url = httpsArtworkURL(from: song.artwork) {
            return url
        }

        var libraryRequest = MusicLibraryRequest<Song>()
        libraryRequest.filter(matching: \.id, equalTo: itemID)
        if let song = try? await libraryRequest.response().items.first,
           let url = httpsArtworkURL(from: song.artwork) {
            return url
        }

        return nil
    }

    private static func httpsArtworkURL(from artwork: Artwork?) -> String? {
        guard let artwork else { return nil }
        for size in [600, 300, 120, 64] {
            guard let raw = artwork.url(width: size, height: size)?.absoluteString,
                  let normalized = ArtworkURLNormalizer.normalize(raw),
                  normalized.hasPrefix("https://") else { continue }
            return normalized
        }
        return nil
    }

    private static func fetchImageData(from urlString: String) async throws -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), !data.isEmpty else {
            return nil
        }
        return data
    }

    private static func iTunesFallback(title: String?, artist: String?) async -> Data? {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedArtist = artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedTitle.isEmpty else { return nil }

        let term = [trimmedTitle, trimmedArtist].filter { !$0.isEmpty }.joined(separator: " ")
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=1") else {
            return nil
        }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first,
              let artwork = (first["artworkUrl100"] as? String) ?? (first["artworkUrl60"] as? String) else {
            return nil
        }

        let large = artwork
            .replacingOccurrences(of: "100x100bb", with: "600x600bb")
            .replacingOccurrences(of: "60x60bb", with: "600x600bb")
        return try? await fetchImageData(from: large)
    }
}
