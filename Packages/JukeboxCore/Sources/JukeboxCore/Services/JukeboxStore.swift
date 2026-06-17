import Foundation

public protocol PlaybackControlling: AnyObject, Sendable {
    func play(item: QueueItem) async throws
    func pause() async
    func resume() async
    func skip() async throws
    func currentElapsed() async -> Double
    func currentIsPlaying() async -> Bool
    func prepareCrossfade() async
}

public actor JukeboxStore {
    public private(set) var nowPlaying: QueueItem?
    public private(set) var elapsed: Double = 0
    public private(set) var isPlaying = false
    public private(set) var connectedClients = 0

    private let database: QueueDatabase
    private var listeners: [UUID: (JukeboxEvent) -> Void] = [:]
    private weak var playback: (any PlaybackControlling)?
    private var skipVoteRequired = 2
    private var lastSessionPersistElapsed: Double = -1

    public init(database: QueueDatabase = QueueDatabase()) {
        self.database = database
    }

    public func setPlaybackController(_ controller: (any PlaybackControlling)?) {
        playback = controller
    }

    public func setConnectedClients(_ count: Int) {
        connectedClients = count
        skipVoteRequired = max(2, Int(ceil(Double(count + 1) / 2.0)))
    }

    public func subscribe(_ handler: @escaping (JukeboxEvent) -> Void) -> UUID {
        let id = UUID()
        listeners[id] = handler
        return id
    }

    public func unsubscribe(_ id: UUID) {
        listeners.removeValue(forKey: id)
    }

    private func broadcast(_ event: JukeboxEvent) {
        for handler in listeners.values {
            handler(event)
        }
    }

    private func trackKey(for item: QueueItem?) -> String? {
        guard let item else { return nil }
        return "\(item.service.rawValue):\(item.musicID)"
    }

    private func skipVoteState() -> SkipVoteState {
        guard let item = nowPlaying, let key = trackKey(for: item) else {
            return SkipVoteState(required: skipVoteRequired)
        }
        let voters = database.skipVoters(trackKey: key)
        return SkipVoteState(votes: voters.count, required: skipVoteRequired, voters: voters)
    }

    public func currentState() async -> NowPlayingState {
        let queue = database.fetchQueue()
        var playbackElapsed = elapsed
        var playbackIsPlaying = isPlaying
        if let playback {
            playbackElapsed = await playback.currentElapsed()
            playbackIsPlaying = await playback.currentIsPlaying()
        }
        return NowPlayingState(
            current: nowPlaying,
            elapsed: playbackElapsed,
            isPlaying: playbackIsPlaying,
            queue: queue,
            skipVote: skipVoteState(),
            connectedClients: connectedClients
        )
    }

    public func fetchQueue() async -> [QueueItem] {
        database.fetchQueue()
    }

    public func addToQueue(_ input: QueueItemInput) async throws -> QueueItem {
        let item = try database.addItem(input)
        let queue = database.fetchQueue()
        broadcast(.queueUpdated(queue))
        broadcast(.state(await currentState()))

        if nowPlaying == nil {
            try await playNext()
        }
        return item
    }

    public func importPlaylist(service: MusicService, playlistID: String, addedBy: String, limit: Int) async throws -> [QueueItem] {
        let tracks = await SearchCoordinator.shared.playlistTracks(
            service: service,
            playlistID: playlistID,
            limit: min(max(limit, 1), 100)
        )

        var added: [QueueItem] = []
        for track in tracks {
            let item = try database.addItem(QueueItemInput(
                title: track.title,
                artist: track.artist,
                artworkURL: track.artworkURL,
                service: track.service,
                musicID: track.musicID,
                duration: track.duration,
                addedBy: addedBy
            ))
            added.append(item)
        }

        let queue = database.fetchQueue()
        broadcast(.queueUpdated(queue))
        broadcast(.state(await currentState()))

        if nowPlaying == nil {
            try await playNext()
        }
        return added
    }

    public func removeFromQueue(id: Int) async throws {
        try database.removeItem(id: id)
        let queue = database.fetchQueue()
        broadcast(.queueUpdated(queue))
        broadcast(.state(await currentState()))
    }

    public func reorderQueue(order: [Int]) async throws {
        try database.reorder(order: order)
        let queue = database.fetchQueue()
        broadcast(.queueUpdated(queue))
        broadcast(.state(await currentState()))
    }

    public func voteSkip(nickname: String) async throws -> Bool {
        guard let item = nowPlaying, let key = trackKey(for: item) else { return false }
        let count = try database.addSkipVote(trackKey: key, voter: nickname)
        broadcast(.state(await currentState()))
        if count >= skipVoteRequired {
            try await skipTrack()
            return true
        }
        return false
    }

    public func skipTrack() async throws {
        if let key = trackKey(for: nowPlaying) {
            database.clearSkipVotes(trackKey: key)
        }
        await playback?.prepareCrossfade()
        try await playNext()
    }

    public func togglePlayback() async throws {
        guard nowPlaying != nil else {
            try await playNext()
            return
        }
        if let playback, await playback.currentIsPlaying() {
            await playback.pause()
            isPlaying = false
        } else {
            await playback?.resume()
            isPlaying = true
        }
        persistSession()
        broadcast(.state(await currentState()))
    }

    public func registerUser(nickname: String) async throws -> UserProfile {
        try database.upsertUser(nickname: nickname)
    }

    public func playNext() async throws {
        if let key = trackKey(for: nowPlaying) {
            database.clearSkipVotes(trackKey: key)
        }
        await playback?.prepareCrossfade()

        guard let next = try database.popFirst() else {
            nowPlaying = nil
            isPlaying = false
            elapsed = 0
            persistSession()
            broadcast(.state(await currentState()))
            return
        }

        nowPlaying = next
        isPlaying = true
        persistSession()
        broadcast(.state(await currentState()))

        if let playback {
            try await playback.play(item: next)
        }
    }

    public func onTrackFinished() async throws {
        try await playNext()
    }

    public func updateProgress() async {
        if let playback {
            elapsed = await playback.currentElapsed()
            isPlaying = await playback.currentIsPlaying()
            if abs(elapsed - lastSessionPersistElapsed) >= 5 {
                persistSession()
                lastSessionPersistElapsed = elapsed
            }
            broadcast(.state(await currentState()))
        }
    }

    private func persistSession() {
        database.saveSession(track: nowPlaying, elapsed: elapsed, isPlaying: isPlaying)
    }

    public func restoreSession() async throws {
        let saved = database.loadSession()
        let queue = database.fetchQueue()

        if let track = saved.track {
            nowPlaying = track
            elapsed = saved.elapsed
            isPlaying = saved.isPlaying
            if let playback, saved.isPlaying {
                try await playback.play(item: track)
            }
            broadcast(.state(await currentState()))
            return
        }

        if nowPlaying == nil, !queue.isEmpty {
            try await playNext()
        } else {
            broadcast(.state(await currentState()))
        }
    }
}
