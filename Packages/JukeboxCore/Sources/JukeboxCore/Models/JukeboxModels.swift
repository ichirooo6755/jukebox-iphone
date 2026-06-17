import Foundation

public enum MusicService: String, Codable, Sendable, CaseIterable {
    case appleMusic = "apple_music"
    case spotify = "spotify"
    case youtube = "youtube"

    public var displayName: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        case .youtube: return "YouTube"
        }
    }
}

public struct QueueItem: Codable, Identifiable, Sendable, Equatable {
    public let id: Int
    public var position: Int
    public var title: String
    public var artist: String
    public var artworkURL: String?
    public var service: MusicService
    public var musicID: String
    public var duration: Int
    public var addedBy: String
    public var addedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, position, title, artist
        case artworkURL = "artwork_url"
        case service
        case musicID = "music_id"
        case duration
        case addedBy = "added_by"
        case addedAt = "added_at"
    }

    public init(
        id: Int,
        position: Int,
        title: String,
        artist: String,
        artworkURL: String?,
        service: MusicService,
        musicID: String,
        duration: Int,
        addedBy: String,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.position = position
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.service = service
        self.musicID = musicID
        self.duration = duration
        self.addedBy = addedBy
        self.addedAt = addedAt
    }
}

public struct QueueItemInput: Codable, Sendable {
    public var title: String
    public var artist: String
    public var artworkURL: String?
    public var service: MusicService
    public var musicID: String
    public var duration: Int
    public var addedBy: String

    enum CodingKeys: String, CodingKey {
        case title, artist
        case artworkURL = "artwork_url"
        case service
        case musicID = "music_id"
        case duration
        case addedBy = "added_by"
    }
}

public struct UserProfile: Codable, Identifiable, Sendable {
    public let id: Int
    public var nickname: String

    public init(id: Int, nickname: String) {
        self.id = id
        self.nickname = nickname
    }
}

public struct SkipVoteState: Codable, Sendable, Equatable {
    public var votes: Int
    public var required: Int
    public var voters: [String]

    enum CodingKeys: String, CodingKey {
        case votes, required, voters
    }

    public init(votes: Int = 0, required: Int = 2, voters: [String] = []) {
        self.votes = votes
        self.required = required
        self.voters = voters
    }

    public static let empty = SkipVoteState()
}

public struct NowPlayingState: Codable, Sendable, Equatable {
    public var current: QueueItem?
    public var elapsed: Double
    public var isPlaying: Bool
    public var queue: [QueueItem]
    public var skipVote: SkipVoteState
    public var connectedClients: Int

    enum CodingKeys: String, CodingKey {
        case current, elapsed
        case isPlaying = "is_playing"
        case queue
        case skipVote = "skip_vote"
        case connectedClients = "connected_clients"
    }

    public init(
        current: QueueItem?,
        elapsed: Double,
        isPlaying: Bool,
        queue: [QueueItem],
        skipVote: SkipVoteState = .empty,
        connectedClients: Int = 0
    ) {
        self.current = current
        self.elapsed = elapsed
        self.isPlaying = isPlaying
        self.queue = queue
        self.skipVote = skipVote
        self.connectedClients = connectedClients
    }

    public static let empty = NowPlayingState(current: nil, elapsed: 0, isPlaying: false, queue: [])
}

public struct SkipVoteRequest: Codable, Sendable {
    public var nickname: String

    public init(nickname: String) {
        self.nickname = nickname
    }
}

public struct TrackSearchResult: Codable, Identifiable, Sendable {
    public var id: String { musicID }
    public var title: String
    public var artist: String
    public var artworkURL: String?
    public var service: MusicService
    public var musicID: String
    public var duration: Int

    enum CodingKeys: String, CodingKey {
        case title, artist
        case artworkURL = "artwork_url"
        case service
        case musicID = "music_id"
        case duration
    }

    public init(
        title: String,
        artist: String,
        artworkURL: String?,
        service: MusicService,
        musicID: String,
        duration: Int
    ) {
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.service = service
        self.musicID = musicID
        self.duration = duration
    }
}

public struct ReorderRequest: Codable, Sendable {
    public var order: [Int]

    public init(order: [Int]) {
        self.order = order
    }
}

public struct NicknameRequest: Codable, Sendable {
    public var nickname: String
}

public struct HostServerStatus: Codable, Sendable {
    public var hostIP: String
    public var port: Int
    public var connectedClients: Int
    public var wifiConnected: Bool

    enum CodingKeys: String, CodingKey {
        case hostIP = "host_ip"
        case port
        case connectedClients = "connected_clients"
        case wifiConnected = "wifi_connected"
    }

    public init(hostIP: String, port: Int, connectedClients: Int, wifiConnected: Bool) {
        self.hostIP = hostIP
        self.port = port
        self.connectedClients = connectedClients
        self.wifiConnected = wifiConnected
    }
}

public enum JukeboxEvent: Codable, Sendable {
    case state(NowPlayingState)
    case queueUpdated([QueueItem])

    enum CodingKeys: String, CodingKey {
        case type, payload
    }

    enum EventType: String, Codable {
        case state
        case queueUpdated = "queue_updated"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EventType.self, forKey: .type)
        switch type {
        case .state:
            self = .state(try container.decode(NowPlayingState.self, forKey: .payload))
        case .queueUpdated:
            self = .queueUpdated(try container.decode([QueueItem].self, forKey: .payload))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .state(let state):
            try container.encode(EventType.state, forKey: .type)
            try container.encode(state, forKey: .payload)
        case .queueUpdated(let items):
            try container.encode(EventType.queueUpdated, forKey: .type)
            try container.encode(items, forKey: .payload)
        }
    }
}
