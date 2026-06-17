import Foundation

private struct PersistedOAuthToken {
    var accessToken: String?
    var refreshToken: String?
    var expiry: Date?
}

private struct OAuthTokenStore {
    private let namespace: String
    private let defaults = UserDefaults.standard

    init(namespace: String) {
        self.namespace = namespace
    }

    func load(participant: String? = nil) -> PersistedOAuthToken {
        PersistedOAuthToken(
            accessToken: defaults.string(forKey: key("access_token", participant: participant)),
            refreshToken: defaults.string(forKey: key("refresh_token", participant: participant)),
            expiry: expiryDate(participant: participant)
        )
    }

    func save(participant: String? = nil, accessToken: String?, refreshToken: String?, expiry: Date?) {
        set(accessToken, for: "access_token", participant: participant)
        if let refreshToken {
            set(refreshToken, for: "refresh_token", participant: participant)
        }
        if let expiry {
            defaults.set(expiry.timeIntervalSince1970, forKey: key("expiry", participant: participant))
        }
    }

    private func set(_ value: String?, for suffix: String, participant: String?) {
        if let value, !value.isEmpty {
            defaults.set(value, forKey: key(suffix, participant: participant))
        }
    }

    private func expiryDate(participant: String?) -> Date? {
        let value = defaults.double(forKey: key("expiry", participant: participant))
        return value > 0 ? Date(timeIntervalSince1970: value) : nil
    }

    private func key(_ suffix: String, participant: String?) -> String {
        if let participant {
            let id = Self.sanitizeParticipant(participant)
            return "jukebox.oauth.\(namespace).participant.\(id).\(suffix)"
        }
        return "jukebox.oauth.\(namespace).\(suffix)"
    }

    private static func sanitizeParticipant(_ participant: String) -> String {
        participant
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
    }
}

public actor SpotifySearchService {
    public static let shared = SpotifySearchService()

    private var accessToken: String?
    private var tokenExpiry: Date?
    private var userAccessToken: String?
    private var userRefreshToken: String?
    private var userTokenExpiry: Date?
    private var pendingStateID: String?

    private let clientID = ProcessInfo.processInfo.environment["SPOTIFY_CLIENT_ID"]
    private let clientSecret = ProcessInfo.processInfo.environment["SPOTIFY_CLIENT_SECRET"]
    private let tokenStore = OAuthTokenStore(namespace: "spotify")

    private init() {
        let persisted = tokenStore.load()
        userAccessToken = persisted.accessToken
        userRefreshToken = persisted.refreshToken
        userTokenExpiry = persisted.expiry
    }

    public func authStatus(baseURL: String) async -> ServiceAuthStatus {
        let configured = clientID?.isEmpty == false && clientSecret?.isEmpty == false
        return ServiceAuthStatus(
            service: .spotify,
            isConfigured: configured,
            isAuthenticated: userAccessToken != nil,
            loginURL: configured ? "\(baseURL)/api/auth/spotify/start" : nil,
            message: configured
                ? (userAccessToken == nil ? "Spotifyにログインできます" : "Spotifyログイン済み")
                : "SPOTIFY_CLIENT_ID / SPOTIFY_CLIENT_SECRET を設定してください"
        )
    }

    public func beginAuthorization(baseURL: String, returnTo: String? = nil) async -> URL? {
        guard let clientID, !clientID.isEmpty else { return nil }
        let id = UUID().uuidString
        pendingStateID = id
        let state = OAuthStatePayload(
            id: id,
            host: baseURL,
            service: .spotify,
            returnTo: returnTo
        ).encoded()
        let redirectURI = OAuthRedirectHelper.redirectURI(baseURL: baseURL, service: .spotify)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "playlist-read-private playlist-read-collaborative user-library-read"),
            URLQueryItem(name: "state", value: state)
        ]
        return components.url
    }

    public func completeAuthorization(code: String, state: String, baseURL: String) async -> Bool {
        guard let payload = OAuthStatePayload.decode(state),
              payload.id == pendingStateID,
              payload.musicService == .spotify,
              let clientID, let clientSecret,
              !clientID.isEmpty, !clientSecret.isEmpty else { return false }

        pendingStateID = nil
        let redirectURI = OAuthRedirectHelper.redirectURI(baseURL: baseURL, service: .spotify)

        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        let credentials = "\(clientID):\(clientSecret)".data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI)
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else { return false }

        userAccessToken = token
        userRefreshToken = json["refresh_token"] as? String
        if let expiresIn = json["expires_in"] as? Int {
            userTokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
        }
        tokenStore.save(accessToken: userAccessToken, refreshToken: userRefreshToken, expiry: userTokenExpiry)
        return true
    }

    public func search(query: String) async -> [TrackSearchResult] {
        guard let token = try? await usableToken() else { return [] }

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

    public func searchPlaylists(query: String) async -> [PlaylistSummary] {
        guard let token = try? await usableToken() else { return [] }

        var components = URLComponents(string: "https://api.spotify.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "playlist"),
            URLQueryItem(name: "limit", value: "20")
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let playlists = json["playlists"] as? [String: Any],
              let items = playlists["items"] as? [[String: Any]] else { return [] }

        return items.compactMap { item in
            guard let id = item["id"] as? String,
                  let name = item["name"] as? String else { return nil }
            let owner = (item["owner"] as? [String: Any])?["display_name"] as? String ?? "Spotify"
            let artwork = (item["images"] as? [[String: Any]])?.first?["url"] as? String
            let total = (item["tracks"] as? [String: Any])?["total"] as? Int
            return PlaylistSummary(
                id: id,
                title: name,
                owner: owner,
                artworkURL: artwork,
                service: .spotify,
                trackCount: total
            )
        }
    }

    public func playlistTracks(playlistID: String, limit: Int) async -> [TrackSearchResult] {
        guard let token = try? await usableToken() else { return [] }

        var components = URLComponents(string: "https://api.spotify.com/v1/playlists/\(playlistID)/tracks")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(min(max(limit, 1), 100))"),
            URLQueryItem(name: "fields", value: "items(track(id,name,duration_ms,artists(name),album(images)))")
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else { return [] }

        return items.compactMap { item in
            guard let track = item["track"] as? [String: Any],
                  let id = track["id"] as? String,
                  let name = track["name"] as? String else { return nil }
            let artists = (track["artists"] as? [[String: Any]])?
                .compactMap { $0["name"] as? String }
                .joined(separator: ", ") ?? "Unknown"
            let duration = (track["duration_ms"] as? Int ?? 0) / 1000
            let artwork = ((track["album"] as? [String: Any])?["images"] as? [[String: Any]])?.first?["url"] as? String
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

    private func usableToken() async throws -> String {
        if let userAccessToken, let expiry = userTokenExpiry, expiry > Date() {
            return userAccessToken
        }
        if userAccessToken != nil, let refreshed = try? await refreshUserToken() {
            return refreshed
        }
        return try await fetchToken()
    }

    private func refreshUserToken() async throws -> String {
        guard let refresh = userRefreshToken, let clientID, let clientSecret else {
            throw SearchServiceError.tokenFailed
        }
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        let credentials = "\(clientID):\(clientSecret)".data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=refresh_token&refresh_token=\(refresh)".data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else {
            throw SearchServiceError.tokenFailed
        }
        userAccessToken = token
        if let expiresIn = json["expires_in"] as? Int {
            userTokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
        }
        tokenStore.save(accessToken: userAccessToken, refreshToken: userRefreshToken, expiry: userTokenExpiry)
        return token
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
    private let clientID = ProcessInfo.processInfo.environment["YOUTUBE_CLIENT_ID"]
    private let clientSecret = ProcessInfo.processInfo.environment["YOUTUBE_CLIENT_SECRET"]
    private var pendingParticipants: [String: String] = [:]
    private let tokenStore = OAuthTokenStore(namespace: "youtube")

    private func normalizedParticipant(_ participant: String?) -> String? {
        guard let participant else { return nil }
        let trimmed = participant.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public func authStatus(baseURL: String, participant: String?) async -> ServiceAuthStatus {
        let configured = clientID?.isEmpty == false && clientSecret?.isEmpty == false
        guard let participant = normalizedParticipant(participant) else {
            return ServiceAuthStatus(
                service: .youtube,
                isConfigured: configured || apiKey?.isEmpty == false,
                isAuthenticated: false,
                loginURL: nil,
                message: "参加後に YouTube へログインできます（参加者ごと）"
            )
        }

        let persisted = tokenStore.load(participant: participant)
        let authenticated = persisted.accessToken != nil
        let encoded = participant.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? participant
        return ServiceAuthStatus(
            service: .youtube,
            isConfigured: configured || apiKey?.isEmpty == false,
            isAuthenticated: authenticated,
            loginURL: configured ? "\(baseURL)/api/auth/youtube/start?participant=\(encoded)" : nil,
            message: configured
                ? (authenticated ? "YouTubeログイン済み（\(participant)）" : "YouTubeにログインできます")
                : "公開検索はYOUTUBE_API_KEY、ログインはYOUTUBE_CLIENT_ID / YOUTUBE_CLIENT_SECRET が必要です"
        )
    }

    public func beginAuthorization(
        baseURL: String,
        participant: String?,
        returnTo: String? = nil
    ) async -> URL? {
        guard let clientID, !clientID.isEmpty,
              let participant = normalizedParticipant(participant) else { return nil }
        let id = UUID().uuidString
        pendingParticipants[id] = participant
        let state = OAuthStatePayload(
            id: id,
            host: baseURL,
            service: .youtube,
            participant: participant,
            returnTo: returnTo
        ).encoded()
        let redirectURI = OAuthRedirectHelper.redirectURI(baseURL: baseURL, service: .youtube)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/youtube.readonly"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "state", value: state)
        ]
        return components.url
    }

    public func completeAuthorization(code: String, state: String, baseURL: String) async -> Bool {
        guard let payload = OAuthStatePayload.decode(state),
              payload.musicService == .youtube,
              let participant = pendingParticipants.removeValue(forKey: payload.id)
                ?? payload.participant,
              let clientID, let clientSecret,
              !clientID.isEmpty, !clientSecret.isEmpty else { return false }

        let redirectURI = OAuthRedirectHelper.redirectURI(baseURL: baseURL, service: .youtube)

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "grant_type", value: "authorization_code")
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else { return false }

        let refresh = json["refresh_token"] as? String
        var expiry: Date?
        if let expiresIn = json["expires_in"] as? Int {
            expiry = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
        }
        tokenStore.save(
            participant: participant,
            accessToken: token,
            refreshToken: refresh ?? tokenStore.load(participant: participant).refreshToken,
            expiry: expiry
        )
        return true
    }

    public func search(query: String, participant: String?) async -> [TrackSearchResult] {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        var queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: "20"),
            URLQueryItem(name: "q", value: query)
        ]
        if let apiKey, !apiKey.isEmpty {
            queryItems.append(URLQueryItem(name: "key", value: apiKey))
        }
        components.queryItems = queryItems
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        if apiKey?.isEmpty != false, let token = try? await usableToken(participant: participant) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        guard (apiKey?.isEmpty == false || request.value(forHTTPHeaderField: "Authorization") != nil),
              let (data, response) = try? await URLSession.shared.data(for: request),
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

    public func searchPlaylists(query: String, participant: String?) async -> [PlaylistSummary] {
        if let token = try? await usableToken(participant: participant) {
            var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlists")!
            components.queryItems = [
                URLQueryItem(name: "part", value: "snippet,contentDetails"),
                URLQueryItem(name: "mine", value: "true"),
                URLQueryItem(name: "maxResults", value: "50")
            ]
            guard let url = components.url else { return [] }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else { return [] }

            return items.compactMap { item in
                guard let id = item["id"] as? String,
                      let snippet = item["snippet"] as? [String: Any],
                      let title = snippet["title"] as? String,
                      title.localizedStandardContains(query) else { return nil }
                let channel = snippet["channelTitle"] as? String ?? "YouTube"
                let thumbs = snippet["thumbnails"] as? [String: Any]
                let medium = thumbs?["medium"] as? [String: Any]
                let count = (item["contentDetails"] as? [String: Any])?["itemCount"] as? Int
                return PlaylistSummary(
                    id: id,
                    title: title,
                    owner: channel,
                    artworkURL: medium?["url"] as? String,
                    service: .youtube,
                    trackCount: count
                )
            }
        }

        guard let apiKey else { return [] }
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "type", value: "playlist"),
            URLQueryItem(name: "maxResults", value: "20"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "key", value: apiKey)
        ]
        guard let url = components.url else { return [] }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else { return [] }

        return items.compactMap { item in
            guard let id = (item["id"] as? [String: Any])?["playlistId"] as? String,
                  let snippet = item["snippet"] as? [String: Any],
                  let title = snippet["title"] as? String else { return nil }
            let channel = snippet["channelTitle"] as? String ?? "YouTube"
            let thumbs = snippet["thumbnails"] as? [String: Any]
            let medium = thumbs?["medium"] as? [String: Any]
            return PlaylistSummary(
                id: id,
                title: title,
                owner: channel,
                artworkURL: medium?["url"] as? String,
                service: .youtube,
                trackCount: nil
            )
        }
    }

    public func playlistTracks(playlistID: String, limit: Int, participant: String?) async -> [TrackSearchResult] {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/playlistItems")!
        var queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails"),
            URLQueryItem(name: "playlistId", value: playlistID),
            URLQueryItem(name: "maxResults", value: "\(min(max(limit, 1), 50))")
        ]
        if let apiKey {
            queryItems.append(URLQueryItem(name: "key", value: apiKey))
        }
        components.queryItems = queryItems
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        if let token = try? await usableToken(participant: participant) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else { return [] }

        return items.compactMap { item in
            guard let snippet = item["snippet"] as? [String: Any],
                  let title = snippet["title"] as? String,
                  let details = item["contentDetails"] as? [String: Any],
                  let videoID = details["videoId"] as? String else { return nil }
            let channel = snippet["videoOwnerChannelTitle"] as? String
                ?? snippet["channelTitle"] as? String
                ?? "YouTube"
            let thumbs = snippet["thumbnails"] as? [String: Any]
            let medium = thumbs?["medium"] as? [String: Any]
            return TrackSearchResult(
                title: title,
                artist: channel,
                artworkURL: medium?["url"] as? String,
                service: .youtube,
                musicID: videoID,
                duration: 0
            )
        }
    }

    private func usableToken(participant: String?) async throws -> String {
        guard let participant = normalizedParticipant(participant) else {
            throw SearchServiceError.tokenFailed
        }
        let persisted = tokenStore.load(participant: participant)
        if let accessToken = persisted.accessToken,
           let expiry = persisted.expiry,
           expiry > Date() {
            return accessToken
        }
        return try await refreshAccessToken(participant: participant)
    }

    private func refreshAccessToken(participant: String) async throws -> String {
        let persisted = tokenStore.load(participant: participant)
        guard let refreshToken = persisted.refreshToken,
              let clientID, let clientSecret else {
            throw SearchServiceError.tokenFailed
        }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else {
            throw SearchServiceError.tokenFailed
        }
        var expiry: Date?
        if let expiresIn = json["expires_in"] as? Int {
            expiry = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
        }
        tokenStore.save(
            participant: participant,
            accessToken: token,
            refreshToken: refreshToken,
            expiry: expiry
        )
        return token
    }
}

public enum SearchServiceError: Error {
    case missingCredentials
    case tokenFailed
}
