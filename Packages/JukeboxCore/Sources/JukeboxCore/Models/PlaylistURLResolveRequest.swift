import Foundation

public struct PlaylistURLResolveRequest: Codable, Sendable {
    public var url: String

    public init(url: String) {
        self.url = url
    }
}
