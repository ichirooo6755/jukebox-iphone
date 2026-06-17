import Foundation

public actor SpotifySearchService {
    public static let shared = SpotifySearchService()

    private var accessToken: String?
    private var tokenExpiry: Date?

    private let clientID = ProcessInfo.processInfo.environment["SPOTIFY_CLIENT_ID"]
    private let clientSecret = ProcessInfo.processInfo.environment["SPOTIFY_CLIENT_SECRET"]

    public func search(query: String) async -> [TrackSearchResult] {
        guard clientID != nil, clientSecret != nil else { return [] }
        guard let token = try? await fetchToken() else { return [] }

        var components = URLComponents(string: "https://api.spotify.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "limit", value: "20")
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tracks = json["tracks"] as? [String: Any],
              let items = tracks["items"] as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item in
            guard let id = item["id"] as? String,
                  let name = item["name"] as? String else { return nil }
            let artists = (item["artists"] as? [[String: Any]])?
                .compactMap { $0["name"] as? String }
                .joined(separator: ", ") ?? "Unknown"
            let duration = (item["duration_ms"] as? Int ?? 0) / 1000
            let artwork = ((item["album"] as? [String: Any])?["images"] as? [[String: Any]])?.first?["url"] as? String
            return TrackSearchResult(
                title: name,
                artist: artists,
                artworkURL: artwork,
                service: .spotify,
                musicID: id,
                duration: duration
            )
        }
    }

    private func fetchToken() async throws -> String {
        if let accessToken, let tokenExpiry, tokenExpiry > Date() {
            return accessToken
        }

        guard let clientID, let clientSecret else {
            throw SearchServiceError.missingCredentials
        }

        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        let credentials = "\(clientID):\(clientSecret)".data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? Int else {
            throw SearchServiceError.tokenFailed
        }

        accessToken = token
        tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
        return token
    }
}

public actor YouTubeSearchService {
    public static let shared = YouTubeSearchService()

    private let apiKey = ProcessInfo.processInfo.environment["YOUTUBE_API_KEY"]

    public func search(query: String) async -> [TrackSearchResult] {
        guard let apiKey else { return [] }

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: "20"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "key", value: apiKey)
        ]
        guard let url = components.url else { return [] }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item in
            guard let id = (item["id"] as? [String: Any])?["videoId"] as? String,
                  let snippet = item["snippet"] as? [String: Any],
                  let title = snippet["title"] as? String else { return nil }
            let channel = snippet["channelTitle"] as? String ?? "Unknown"
            let thumbs = snippet["thumbnails"] as? [String: Any]
            let medium = thumbs?["medium"] as? [String: Any]
            let artwork = medium?["url"] as? String
            return TrackSearchResult(
                title: title,
                artist: channel,
                artworkURL: artwork,
                service: .youtube,
                musicID: id,
                duration: 0
            )
        }
    }
}

public enum SearchServiceError: Error {
    case missingCredentials
    case tokenFailed
}
