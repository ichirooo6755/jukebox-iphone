import Foundation

public enum QueuePlaybackMode: String, Codable, Sendable, CaseIterable {
    case singleTrack = "single_track"
    case playlistRoulette = "playlist_roulette"

    public var displayName: String {
        switch self {
        case .singleTrack: return "一曲ずつ"
        case .playlistRoulette: return "プレイリスト選択"
        }
    }
}

public struct PlaylistLaneTrack: Codable, Sendable, Equatable, Identifiable {
    public var id: String { musicID }
    public var title: String
    public var artist: String
    public var artworkURL: String?
    public var service: MusicService
    public var musicID: String
    public var duration: Int

    enum CodingKeys: String, CodingKey {
        case title, artist, service, duration
        case artworkURL = "artwork_url"
        case musicID = "music_id"
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

public struct PlaylistLane: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public var participant: String
    public var displayName: String?
    public var avatarURL: String?
    public var service: MusicService
    public var playlistID: String
    public var playlistTitle: String
    public var playlistArtworkURL: String?
    public var tracks: [PlaylistLaneTrack]
    public var position: Int
    public var joinedAt: Date
    public var color: String

    enum CodingKeys: String, CodingKey {
        case id, participant, service, tracks, position, color
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case playlistID = "playlist_id"
        case playlistTitle = "playlist_title"
        case playlistArtworkURL = "playlist_artwork_url"
        case joinedAt = "joined_at"
    }

    public var remainingCount: Int {
        max(0, tracks.count - position)
    }

    public var isActive: Bool {
        remainingCount > 0
    }
}

public struct PlaylistLaneImportRequest: Codable, Sendable {
    public var service: MusicService
    public var playlistID: String
    public var addedBy: String
    public var limit: Int
    public var displayName: String?
    public var avatarURL: String?
    public var playlistTitle: String?
    public var playlistArtworkURL: String?

    enum CodingKeys: String, CodingKey {
        case service, limit
        case playlistID = "playlist_id"
        case addedBy = "added_by"
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case playlistTitle = "playlist_title"
        case playlistArtworkURL = "playlist_artwork_url"
    }

    public init(
        service: MusicService,
        playlistID: String,
        addedBy: String,
        limit: Int,
        displayName: String? = nil,
        avatarURL: String? = nil,
        playlistTitle: String? = nil,
        playlistArtworkURL: String? = nil
    ) {
        self.service = service
        self.playlistID = playlistID
        self.addedBy = addedBy
        self.limit = limit
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.playlistTitle = playlistTitle
        self.playlistArtworkURL = playlistArtworkURL
    }
}

public struct PlaylistTracksImportRequest: Codable, Sendable {
    public var service: MusicService
    public var addedBy: String
    public var displayName: String?
    public var avatarURL: String?
    public var playlistID: String?
    public var playlistTitle: String
    public var playlistArtworkURL: String?
    public var tracks: [PlaylistLaneTrack]

    enum CodingKeys: String, CodingKey {
        case service, tracks
        case addedBy = "added_by"
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case playlistID = "playlist_id"
        case playlistTitle = "playlist_title"
        case playlistArtworkURL = "playlist_artwork_url"
    }

    public init(
        service: MusicService,
        addedBy: String,
        playlistTitle: String,
        tracks: [PlaylistLaneTrack],
        displayName: String? = nil,
        avatarURL: String? = nil,
        playlistID: String? = nil,
        playlistArtworkURL: String? = nil
    ) {
        self.service = service
        self.addedBy = addedBy
        self.playlistTitle = playlistTitle
        self.tracks = tracks
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.playlistID = playlistID
        self.playlistArtworkURL = playlistArtworkURL
    }
}

public struct PlaylistTracksImportResponse: Codable, Sendable {
    public var mode: QueuePlaybackMode
    public var lane: PlaylistLane?
    public var queueItems: [QueueItem]?

    enum CodingKeys: String, CodingKey {
        case mode, lane
        case queueItems = "queue_items"
    }
}

public struct PlaybackModeRequest: Codable, Sendable {
    public var mode: QueuePlaybackMode

    public init(mode: QueuePlaybackMode) {
        self.mode = mode
    }
}

public struct PlaylistRouletteState: Codable, Sendable, Equatable {
    public var mode: QueuePlaybackMode
    public var lanes: [PlaylistLane]
    public var lastRouletteParticipant: String?
    public var sessionStartedAt: Date?

    enum CodingKeys: String, CodingKey {
        case mode, lanes
        case lastRouletteParticipant = "last_roulette_participant"
        case sessionStartedAt = "session_started_at"
    }

    public static let empty = PlaylistRouletteState(
        mode: .singleTrack,
        lanes: [],
        lastRouletteParticipant: nil,
        sessionStartedAt: nil
    )
}

public enum PlaylistLanePalette {
    public static let colors = [
        "#3B82F6", "#EC4899", "#22C55E", "#F59E0B", "#A855F7", "#06B6D4", "#EF4444", "#84CC16"
    ]

    public static func color(for participant: String, index: Int) -> String {
        let hash = participant.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[(hash + index) % colors.count]
    }
}
