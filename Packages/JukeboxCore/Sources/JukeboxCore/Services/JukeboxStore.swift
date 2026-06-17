import Foundation

public protocol PlaybackControlling: AnyObject, Sendable {
    func play(item: QueueItem) async throws
    func pause() async
    func resume() async
    func skip() async throws
    func currentElapsed() async -> Double
    func currentIsPlaying() async -> Bool
}

public actor JukeboxStore {
    public private(set) var nowPlaying: QueueItem?
    public private(set) var elapsed: Double = 0
    public private(set) var isPlaying = false

    private let database: QueueDatabase
    private var listeners: [UUID: (JukeboxEvent) -> Void] = [:]
    private weak var playback: (any PlaybackControlling)?

    public init(database: QueueDatabase = QueueDatabase()) {
        self.database = database
    }

    public func setPlaybackController(_ controller: (any PlaybackControlling)?) {
        playback = controller
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
            queue: queue
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

    public func skipTrack() async throws {
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
        broadcast(.state(await currentState()))
    }

    public func registerUser(nickname: String) async throws -> UserProfile {
        try database.upsertUser(nickname: nickname)
    }

    public func playNext() async throws {
        guard let next = try database.popFirst() else {
            nowPlaying = nil
            isPlaying = false
            elapsed = 0
            broadcast(.state(await currentState()))
            return
        }

        nowPlaying = next
        isPlaying = true
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
            broadcast(.state(await currentState()))
        }
    }

    public func restoreSession() async throws {
        let queue = database.fetchQueue()
        if nowPlaying == nil, !queue.isEmpty {
            try await playNext()
        } else {
            broadcast(.state(await currentState()))
        }
    }
}
