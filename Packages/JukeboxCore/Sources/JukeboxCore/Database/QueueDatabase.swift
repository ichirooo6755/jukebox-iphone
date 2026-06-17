import Foundation
import SQLite3

public final class QueueDatabase: @unchecked Sendable {
    private var db: OpaquePointer?
    private let dbPath: String
    private let lock = NSLock()

    public init(path: String? = nil) {
        if let path {
            dbPath = path
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            dbPath = dir.appendingPathComponent("jukebox.sqlite").path
        }
        open()
        migrate()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    private func open() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            fatalError("Failed to open database at \(dbPath)")
        }
    }

    private func migrate() {
        exec("""
        CREATE TABLE IF NOT EXISTS queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            position INTEGER NOT NULL,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            artwork_url TEXT,
            service TEXT NOT NULL,
            music_id TEXT NOT NULL,
            duration INTEGER NOT NULL DEFAULT 0,
            added_by TEXT NOT NULL,
            added_at REAL NOT NULL
        );
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nickname TEXT NOT NULL UNIQUE
        );
        """)
    }

    private func exec(_ sql: String) {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let message = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            fatalError("SQLite error: \(message)")
        }
    }

    public func fetchQueue() -> [QueueItem] {
        lock.lock()
        defer { lock.unlock() }
        return query("SELECT id, position, title, artist, artwork_url, service, music_id, duration, added_by, added_at FROM queue ORDER BY position ASC")
    }

    public func addItem(_ input: QueueItemInput) throws -> QueueItem {
        lock.lock()
        defer { lock.unlock() }
        let position = (fetchQueue().map(\.position).max() ?? -1) + 1
        let addedAt = Date().timeIntervalSince1970
        let sql = """
        INSERT INTO queue (position, title, artist, artwork_url, service, music_id, duration, added_by, added_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(position))
        sqlite3_bind_text(stmt, 2, input.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, input.artist, -1, SQLITE_TRANSIENT)
        if let url = input.artworkURL {
            sqlite3_bind_text(stmt, 4, url, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 4)
        }
        sqlite3_bind_text(stmt, 5, input.service.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, input.musicID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 7, Int32(input.duration))
        sqlite3_bind_text(stmt, 8, input.addedBy, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 9, addedAt)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.insertFailed
        }

        let id = Int(sqlite3_last_insert_rowid(db))
        return QueueItem(
            id: id,
            position: position,
            title: input.title,
            artist: input.artist,
            artworkURL: input.artworkURL,
            service: input.service,
            musicID: input.musicID,
            duration: input.duration,
            addedBy: input.addedBy,
            addedAt: Date(timeIntervalSince1970: addedAt)
        )
    }

    public func removeItem(id: Int) throws {
        lock.lock()
        defer { lock.unlock() }
        try deleteWhere("id = ?", bindings: [.int(id)])
        try reindexPositions()
    }

    public func reorder(order: [Int]) throws {
        lock.lock()
        defer { lock.unlock() }
        for (index, id) in order.enumerated() {
            try updatePosition(id: id, position: index)
        }
    }

    public func popFirst() throws -> QueueItem? {
        lock.lock()
        defer { lock.unlock() }
        guard let first = fetchQueue().first else { return nil }
        try removeItem(id: first.id)
        return first
    }

    public func upsertUser(nickname: String) throws -> UserProfile {
        lock.lock()
        defer { lock.unlock() }
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DatabaseError.invalidNickname }

        if let existing = fetchUser(nickname: trimmed) {
            return existing
        }

        let sql = "INSERT INTO users (nickname) VALUES (?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, trimmed, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.insertFailed
        }
        return UserProfile(id: Int(sqlite3_last_insert_rowid(db)), nickname: trimmed)
    }

    public func fetchUser(nickname: String) -> UserProfile? {
        lock.lock()
        defer { lock.unlock() }
        let sql = "SELECT id, nickname FROM users WHERE nickname = ? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, nickname, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return UserProfile(id: Int(sqlite3_column_int(stmt, 0)), nickname: String(cString: sqlite3_column_text(stmt, 1)))
    }

    private func reindexPositions() throws {
        let items = fetchQueue()
        for (index, item) in items.enumerated() {
            try updatePosition(id: item.id, position: index)
        }
    }

    private func updatePosition(id: Int, position: Int) throws {
        try deleteWhere("id = \(id)", bindings: [], isUpdate: true, updateSQL: "UPDATE queue SET position = ? WHERE id = ?;", bindings2: [.int(position), .int(id)])
    }

    private func deleteWhere(_ whereClause: String, bindings: [Binding], isUpdate: Bool = false, updateSQL: String = "", bindings2: [Binding] = []) throws {
        if isUpdate {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, updateSQL, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            defer { sqlite3_finalize(stmt) }
            try bind(bindings2, to: stmt)
            guard sqlite3_step(stmt) == SQLITE_DONE else { throw DatabaseError.updateFailed }
            return
        }

        let sql = "DELETE FROM queue WHERE \(whereClause);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }
        defer { sqlite3_finalize(stmt) }
        try bind(bindings, to: stmt)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw DatabaseError.deleteFailed }
    }

    private enum Binding {
        case int(Int)
        case text(String)
    }

    private func bind(_ bindings: [Binding], to stmt: OpaquePointer?) throws {
        for (i, binding) in bindings.enumerated() {
            let index = Int32(i + 1)
            switch binding {
            case .int(let value):
                sqlite3_bind_int(stmt, index, Int32(value))
            case .text(let value):
                sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT)
            }
        }
    }

    private func query(_ sql: String) -> [QueueItem] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var items: [QueueItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let artwork: String? = {
                guard let ptr = sqlite3_column_text(stmt, 4) else { return nil }
                return String(cString: ptr)
            }()
            let serviceRaw = String(cString: sqlite3_column_text(stmt, 5))
            items.append(QueueItem(
                id: Int(sqlite3_column_int(stmt, 0)),
                position: Int(sqlite3_column_int(stmt, 1)),
                title: String(cString: sqlite3_column_text(stmt, 2)),
                artist: String(cString: sqlite3_column_text(stmt, 3)),
                artworkURL: artwork,
                service: MusicService(rawValue: serviceRaw) ?? .appleMusic,
                musicID: String(cString: sqlite3_column_text(stmt, 6)),
                duration: Int(sqlite3_column_int(stmt, 7)),
                addedBy: String(cString: sqlite3_column_text(stmt, 8)),
                addedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 9))
            ))
        }
        return items
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum DatabaseError: Error, LocalizedError {
    case prepareFailed
    case insertFailed
    case updateFailed
    case deleteFailed
    case invalidNickname

    public var errorDescription: String? {
        switch self {
        case .prepareFailed: return "データベースの準備に失敗しました"
        case .insertFailed: return "追加に失敗しました"
        case .updateFailed: return "更新に失敗しました"
        case .deleteFailed: return "削除に失敗しました"
        case .invalidNickname: return "ニックネームを入力してください"
        }
    }
}
