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
        self.artworkURL = ArtworkURLNormalizer.normalize(artworkURL)
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

    public init(
        title: String,
        artist: String,
        artworkURL: String?,
        service: MusicService,
        musicID: String,
        duration: Int,
        addedBy: String
    ) {
        self.title = title
        self.artist = artist
        self.artworkURL = ArtworkURLNormalizer.normalize(artworkURL)
        self.service = service
        self.musicID = musicID
        self.duration = duration
        self.addedBy = addedBy
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
    public var playbackMode: QueuePlaybackMode
    public var playlistLanes: [PlaylistLane]
    public var lastRouletteParticipant: String?
    public var sessionStartedAt: Date?

    enum CodingKeys: String, CodingKey {
        case current, elapsed
        case isPlaying = "is_playing"
        case queue
        case skipVote = "skip_vote"
        case connectedClients = "connected_clients"
        case playbackMode = "playback_mode"
        case playlistLanes = "playlist_lanes"
        case lastRouletteParticipant = "last_roulette_participant"
        case sessionStartedAt = "session_started_at"
    }

    public init(
        current: QueueItem?,
        elapsed: Double,
        isPlaying: Bool,
        queue: [QueueItem],
        skipVote: SkipVoteState = .empty,
        connectedClients: Int = 0,
        playbackMode: QueuePlaybackMode = .singleTrack,
        playlistLanes: [PlaylistLane] = [],
        lastRouletteParticipant: String? = nil,
        sessionStartedAt: Date? = nil
    ) {
        self.current = current
        self.elapsed = elapsed
        self.isPlaying = isPlaying
        self.queue = queue
        self.skipVote = skipVote
        self.connectedClients = connectedClients
        self.playbackMode = playbackMode
        self.playlistLanes = playlistLanes
        self.lastRouletteParticipant = lastRouletteParticipant
        self.sessionStartedAt = sessionStartedAt
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
        self.artworkURL = ArtworkURLNormalizer.normalize(artworkURL)
        self.service = service
        self.musicID = musicID
        self.duration = duration
    }
}

public struct UnifiedSearchResult: Codable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case track
        case playlist
        case artist
    }

    public var id: String
    public var kind: Kind
    public var title: String
    public var subtitle: String
    public var artworkURL: String?
    public var service: MusicService
    public var musicID: String?
    public var duration: Int?
    public var trackCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, kind, title, subtitle
        case artworkURL = "artwork_url"
        case service
        case musicID = "music_id"
        case duration
        case trackCount = "track_count"
    }

    public init(
        id: String,
        kind: Kind,
        title: String,
        subtitle: String,
        artworkURL: String?,
        service: MusicService,
        musicID: String? = nil,
        duration: Int? = nil,
        trackCount: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = ArtworkURLNormalizer.normalize(artworkURL)
        self.service = service
        self.musicID = musicID
        self.duration = duration
        self.trackCount = trackCount
    }
}

public struct PlaylistSummary: Codable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var owner: String
    public var artworkURL: String?
    public var service: MusicService
    public var trackCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, owner
        case artworkURL = "artwork_url"
        case service
        case trackCount = "track_count"
    }

    public init(
        id: String,
        title: String,
        owner: String,
        artworkURL: String?,
        service: MusicService,
        trackCount: Int?
    ) {
        self.id = id
        self.title = title
        self.owner = owner
        self.artworkURL = ArtworkURLNormalizer.normalize(artworkURL)
        self.service = service
        self.trackCount = trackCount
    }
}

public struct ServiceAuthStatus: Codable, Sendable {
    public var service: MusicService
    public var isConfigured: Bool
    public var isAuthenticated: Bool
    public var loginURL: String?
    public var message: String
    public var displayName: String?
    public var avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case service
        case isConfigured = "is_configured"
        case isAuthenticated = "is_authenticated"
        case loginURL = "login_url"
        case message
        case displayName = "display_name"
        case avatarURL = "avatar_url"
    }

    public init(
        service: MusicService,
        isConfigured: Bool,
        isAuthenticated: Bool,
        loginURL: String?,
        message: String,
        displayName: String? = nil,
        avatarURL: String? = nil
    ) {
        self.service = service
        self.isConfigured = isConfigured
        self.isAuthenticated = isAuthenticated
        self.loginURL = loginURL
        self.message = message
        self.displayName = displayName
        self.avatarURL = avatarURL
    }
}

public struct ArtistImportRequest: Codable, Sendable {
    public var service: MusicService
    public var artistID: String
    public var addedBy: String
    public var limit: Int

    enum CodingKeys: String, CodingKey {
        case service
        case artistID = "artist_id"
        case addedBy = "added_by"
        case limit
    }

    public init(service: MusicService, artistID: String, addedBy: String, limit: Int) {
        self.service = service
        self.artistID = artistID
        self.addedBy = addedBy
        self.limit = limit
    }
}

public struct PlaylistImportRequest: Codable, Sendable {
    public var service: MusicService
    public var playlistID: String
    public var addedBy: String
    public var limit: Int

    enum CodingKeys: String, CodingKey {
        case service
        case playlistID = "playlist_id"
        case addedBy = "added_by"
        case limit
    }

    public init(service: MusicService, playlistID: String, addedBy: String, limit: Int) {
        self.service = service
        self.playlistID = playlistID
        self.addedBy = addedBy
        self.limit = limit
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

    public init(nickname: String) {
        self.nickname = nickname
    }
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
