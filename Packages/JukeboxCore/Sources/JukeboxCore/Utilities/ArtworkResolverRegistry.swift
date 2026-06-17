import Foundation

public actor ArtworkResolverRegistry {
    public static let shared = ArtworkResolverRegistry()

    public struct Request: Sendable {
        public let service: MusicService
        public let musicID: String
        public let title: String?
        public let artist: String?

        public init(service: MusicService, musicID: String, title: String? = nil, artist: String? = nil) {
            self.service = service
            self.musicID = musicID
            self.title = title
            self.artist = artist
        }
    }

    private var handler: (@Sendable (Request) async -> Data?)?

    private init() {}

    public func setHandler(_ handler: @escaping @Sendable (Request) async -> Data?) {
        self.handler = handler
    }

    public func resolveImageData(_ request: Request) async -> Data? {
        await handler?(request)
    }
}
