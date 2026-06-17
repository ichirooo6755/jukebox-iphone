import Foundation

public struct ParsedPlaylistURL: Sendable, Equatable {
    public var service: MusicService
    public var playlistID: String

    public init(service: MusicService, playlistID: String) {
        self.service = service
        self.playlistID = playlistID
    }
}

public enum PlaylistURLParser {
    public static func parse(_ raw: String) -> ParsedPlaylistURL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let spotify = parseSpotify(trimmed) { return spotify }
        if let youtube = parseYouTube(trimmed) { return youtube }
        if let apple = parseAppleMusic(trimmed) { return apple }
        return nil
    }

    private static func parseSpotify(_ value: String) -> ParsedPlaylistURL? {
        if value.hasPrefix("spotify:playlist:") {
            let id = value.replacingOccurrences(of: "spotify:playlist:", with: "")
            return id.isEmpty ? nil : ParsedPlaylistURL(service: .spotify, playlistID: id)
        }
        guard let url = URL(string: value), let host = url.host?.lowercased() else { return nil }
        guard host.contains("spotify.com") else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        if let index = parts.firstIndex(of: "playlist"), index + 1 < parts.count {
            let id = parts[index + 1].split(separator: "?").first.map(String.init) ?? parts[index + 1]
            return ParsedPlaylistURL(service: .spotify, playlistID: id)
        }
        return nil
    }

    private static func parseYouTube(_ value: String) -> ParsedPlaylistURL? {
        guard let url = URL(string: value),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let host = url.host?.lowercased() ?? ""
        guard host.contains("youtube.com") || host.contains("youtu.be") else { return nil }
        if let list = components.queryItems?.first(where: { $0.name == "list" })?.value,
           !list.isEmpty, list.hasPrefix("PL") || list.hasPrefix("UU") || list.hasPrefix("OL") {
            return ParsedPlaylistURL(service: .youtube, playlistID: list)
        }
        return nil
    }

    private static func parseAppleMusic(_ value: String) -> ParsedPlaylistURL? {
        guard let url = URL(string: value) else { return nil }
        let host = url.host?.lowercased() ?? ""
        guard host.contains("music.apple.com") else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard let index = parts.firstIndex(of: "playlist"), index + 1 < parts.count else { return nil }
        let id = parts[index + 1]
        return id.isEmpty ? nil : ParsedPlaylistURL(service: .appleMusic, playlistID: id)
    }
}
