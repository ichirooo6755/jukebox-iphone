import Foundation

public struct OAuthStatePayload: Codable, Sendable {
    public let id: String
    public let host: String
    public let service: String
    public let participant: String?
    public let returnTo: String?

    public init(
        id: String,
        host: String,
        service: MusicService,
        participant: String? = nil,
        returnTo: String? = nil
    ) {
        self.id = id
        self.host = host
        self.service = service.rawValue
        self.participant = participant
        self.returnTo = returnTo
    }

    public var musicService: MusicService? {
        MusicService(rawValue: service)
    }

    public func encoded() -> String {
        guard let data = try? JSONEncoder().encode(self) else { return id }
        return Self.base64URLEncode(data)
    }

    public static func decode(_ state: String) -> OAuthStatePayload? {
        if let data = base64URLDecode(state),
           let payload = try? JSONDecoder().decode(OAuthStatePayload.self, from: data) {
            return payload
        }
        return nil
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - (base64.count % 4)
        if padding < 4 {
            base64 += String(repeating: "=", count: padding)
        }
        return Data(base64Encoded: base64)
    }
}

public enum OAuthRedirectHelper {
    public static let defaultPublicRedirectURI = "https://jukebox-join-ichirooo6755.netlify.app/oauth/callback.html"

    public static func publicRedirectURI() -> String? {
        let candidates = [
            ProcessInfo.processInfo.environment["OAUTH_PUBLIC_REDIRECT_URI"],
            ProcessInfo.processInfo.environment["YOUTUBE_OAUTH_REDIRECT_URI"],
        ]
        for value in candidates {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty, trimmed.hasPrefix("https://") {
                return trimmed
            }
        }
        return defaultPublicRedirectURI
    }

    public static func redirectURI(baseURL: String, service: MusicService) -> String {
        if let publicURI = publicRedirectURI() {
            return publicURI
        }
        return "\(baseURL)/api/auth/\(service.rawValue)/callback"
    }

    public static func usesPublicRedirect() -> Bool {
        publicRedirectURI() != nil
    }
}
