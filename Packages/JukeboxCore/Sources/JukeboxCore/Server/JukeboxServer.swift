import Foundation
import FlyingFox

public final class JukeboxWebSocketHandler: WSMessageHandler, @unchecked Sendable {
    private let store: JukeboxStore
    private let encoder = JSONEncoder()
    private var subscriptionID: UUID?
    private let queue = DispatchQueue(label: "jukebox.ws.clients")
    private var outboundContinuations: [UUID: AsyncStream<WSMessage>.Continuation] = [:]

    public init(store: JukeboxStore) {
        self.store = store
        encoder.dateEncodingStrategy = .iso8601
    }

    public func makeMessages(for client: AsyncStream<WSMessage>) async throws -> AsyncStream<WSMessage> {
        let clientID = UUID()
        let (stream, continuation) = AsyncStream<WSMessage>.makeStream()

        queue.sync {
            outboundContinuations[clientID] = continuation
        }

        if subscriptionID == nil {
            subscriptionID = await store.subscribe { [weak self] event in
                self?.broadcast(event)
            }
        }

        let state = await store.currentState()
        if let data = try? encoder.encode(JukeboxEvent.state(state)),
           let text = String(data: data, encoding: .utf8) {
            continuation.yield(.text(text))
        }

        Task {
            for await message in client {
                if case .close = message { break }
            }
            self.removeClient(clientID)
        }

        return stream
    }

    private func removeClient(_ id: UUID) {
        queue.sync {
            outboundContinuations.removeValue(forKey: id)?.finish()
        }
    }

    private func broadcast(_ event: JukeboxEvent) {
        guard let data = try? encoder.encode(event),
              let text = String(data: data, encoding: .utf8) else { return }
        queue.sync {
            for continuation in outboundContinuations.values {
                continuation.yield(.text(text))
            }
        }
    }

    public var clientCount: Int {
        queue.sync { outboundContinuations.count }
    }
}

public actor JukeboxServer {
    public static let defaultPort: UInt16 = 8765

    private let store: JukeboxStore
    private let webRoot: URL?
    private var server: HTTPServer?
    private var serverTask: Task<Void, Never>?
    private var bonjourService: NetService?
    private let wsHandler: JukeboxWebSocketHandler
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(store: JukeboxStore, webRoot: URL? = nil) {
        self.store = store
        self.webRoot = webRoot
        wsHandler = JukeboxWebSocketHandler(store: store)
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    public func start(port: UInt16 = defaultPort) async throws {
        await store.setConnectedClients(wsHandler.clientCount)
        let http = HTTPServer(port: port)
        server = http

        await http.appendRoute("GET /api/artwork", to: ArtworkProxyHandler())

        await http.appendRoute("GET /api/health") { _ in
            HTTPResponse(statusCode: .ok, body: Data("ok".utf8))
        }

        await http.appendRoute("GET /api/status") { [weak self] _ in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            let status = await self.makeStatus(port: port)
            return try await self.jsonResponse(status)
        }

        await http.appendRoute("GET /api/auth/status") { [weak self] (request: HTTPRequest) in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            let participant = Self.participant(from: request)
            let statuses = await SearchCoordinator.shared.authStatuses(
                baseURL: Self.baseURL(for: request, port: port),
                participant: participant
            )
            return try await self.jsonResponse(statuses)
        }

        await http.appendRoute("GET /api/auth/:service/start") { [weak self] (request: HTTPRequest, service: String) in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            let participant = Self.participant(from: request)
            let returnTo = request.query.first(where: { $0.name == "return" })?.value
            guard let musicService = MusicService(rawValue: service),
                  let url = await SearchCoordinator.shared.beginAuth(
                    service: musicService,
                    baseURL: Self.baseURL(for: request, port: port),
                    participant: participant,
                    returnTo: returnTo
                  ) else {
                return HTTPResponse(statusCode: .badRequest, body: Data("auth is not configured".utf8))
            }
            var headers = HTTPHeaders()
            headers.addValue(url.absoluteString, for: .location)
            return HTTPResponse(statusCode: .found, headers: headers)
        }

        await http.appendRoute("GET /api/auth/:service/callback") { [weak self] (request: HTTPRequest, service: String) in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            guard let musicService = MusicService(rawValue: service),
                  let code = request.query.first(where: { $0.name == "code" })?.value,
                  let state = request.query.first(where: { $0.name == "state" })?.value else {
                return HTTPResponse(statusCode: .badRequest, body: Data("missing code or state".utf8))
            }
            let baseURL = Self.baseURL(for: request, port: port)
            let ok = await SearchCoordinator.shared.completeAuth(
                service: musicService,
                code: code,
                state: state,
                baseURL: baseURL
            )
            let payload = OAuthStatePayload.decode(state)
            let returnBase = payload?.host ?? baseURL
            let onboardQuery = payload?.returnTo == "onboard" ? "onboard=1&" : ""
            let redirectURL = "\(returnBase)/?\(onboardQuery)auth=\(service)&ok=\(ok ? "1" : "0")"
            let html = """
            <!doctype html><html lang="ja"><meta name="viewport" content="width=device-width,initial-scale=1">
            <body style="font-family:-apple-system;background:#111;color:#fff;padding:24px;text-align:center">
            <p>\(ok ? "戻っています…" : "ログインに失敗しました")</p>
            <script>location.replace('\(redirectURL)')</script>
            </body></html>
            """
            return HTTPResponse(
                statusCode: ok ? .ok : .badRequest,
                headers: [.contentType: "text/html; charset=utf-8"],
                body: Data(html.utf8)
            )
        }

        await http.appendRoute("GET /api/state") { [weak self] _ in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            return try await self.jsonResponse(await self.store.currentState())
        }

        await http.appendRoute("GET /api/queue") { [weak self] _ in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            return try await self.jsonResponse(await self.store.fetchQueue())
        }

        await http.appendRoute("POST /api/queue") { [weak self] (request: HTTPRequest) in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            let body = try await request.bodyData
            let input = try self.decoder.decode(QueueItemInput.self, from: body)
            let item = try await self.store.addToQueue(input)
            return try await self.jsonResponse(item, status: .created)
        }

        await http.appendRoute("DELETE /api/queue/:id") { [weak self] (_: HTTPRequest, id: Int) in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            try await self.store.removeFromQueue(id: id)
            return HTTPResponse(statusCode: .noContent)
        }

        await http.appendRoute("PUT /api/queue/reorder") { [weak self] (request: HTTPRequest) in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            let body = try await request.bodyData
            let reorder = try self.decoder.decode(ReorderRequest.self, from: body)
            try await self.store.reorderQueue(order: reorder.order)
            return HTTPResponse(statusCode: .noContent)
        }

        await http.appendRoute("POST /api/playback/skip") { [weak self] _ in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            try await self.store.skipTrack()
            return HTTPResponse(statusCode: .noContent)
        }

        await http.appendRoute("POST /api/playback/toggle") { [weak self] _ in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            try await self.store.togglePlayback()
            return HTTPResponse(statusCode: .noContent)
        }

        await http.appendRoute("POST /api/playback/vote-skip") { [weak self] (request: HTTPRequest) in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            let body = try await request.bodyData
            let req = try self.decoder.decode(SkipVoteRequest.self, from: body)
            let skipped = try await self.store.voteSkip(nickname: req.nickname)
            return try await self.jsonResponse(["skipped": skipped])
        }

        await http.appendRoute("POST /api/users") { [weak self] (request: HTTPRequest) in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            let body = try await request.bodyData
            let req = try self.decoder.decode(NicknameRequest.self, from: body)
            let user = try await self.store.registerUser(nickname: req.nickname)
            return try await self.jsonResponse(user, status: .created)
        }

        await http.appendRoute("GET /api/search/unified") { [weak self] (request: HTTPRequest) in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            let query = request.query.first(where: { $0.name == "q" })?.value ?? ""
            let serviceRaw = request.query.first(where: { $0.name == "service" })?.value ?? "apple_music"
            let service = MusicService(rawValue: serviceRaw) ?? .appleMusic
            let participant = Self.participant(from: request)
            let results = await SearchCoordinator.shared.unifiedSearch(
                query: query,
                service: service,
                participant: participant
            )
            return try await self.jsonResponse(results)
        }

        await http.appendRoute("GET /api/search") { [weak self] (request: HTTPRequest) in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            let query = request.query.first(where: { $0.name == "q" })?.value ?? ""
            let serviceRaw = request.query.first(where: { $0.name == "service" })?.value ?? "apple_music"
            let service = MusicService(rawValue: serviceRaw) ?? .appleMusic
            let participant = Self.participant(from: request)
            let results = await SearchCoordinator.shared.search(
                query: query,
                service: service,
                participant: participant
            )
            return try await self.jsonResponse(results)
        }

        await http.appendRoute("GET /api/playlists") { [weak self] (request: HTTPRequest) in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            let query = request.query.first(where: { $0.name == "q" })?.value ?? ""
            let serviceRaw = request.query.first(where: { $0.name == "service" })?.value ?? "apple_music"
            let service = MusicService(rawValue: serviceRaw) ?? .appleMusic
            let participant = Self.participant(from: request)
            let results = await SearchCoordinator.shared.searchPlaylists(
                query: query,
                service: service,
                participant: participant
            )
            return try await self.jsonResponse(results)
        }

        await http.appendRoute("POST /api/playlists/import") { [weak self] (request: HTTPRequest) in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            let body = try await request.bodyData
            let importRequest = try self.decoder.decode(PlaylistImportRequest.self, from: body)
            let added = try await self.store.importPlaylist(
                service: importRequest.service,
                playlistID: importRequest.playlistID,
                addedBy: importRequest.addedBy,
                limit: importRequest.limit
            )
            return try await self.jsonResponse(added, status: .created)
        }

        await http.appendRoute("POST /api/artists/import") { [weak self] (request: HTTPRequest) in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            let body = try await request.bodyData
            let importRequest = try self.decoder.decode(ArtistImportRequest.self, from: body)
            let added = try await self.store.importArtist(
                service: importRequest.service,
                artistID: importRequest.artistID,
                addedBy: importRequest.addedBy,
                limit: importRequest.limit
            )
            return try await self.jsonResponse(added, status: .created)
        }

        await http.appendRoute("GET /ws", to: .webSocket(wsHandler))

        if let webRoot {
            let staticFiles = StaticWebFilesHandler(root: webRoot)
            await http.appendRoute("GET /", to: staticFiles)
            await http.appendRoute("GET /*", to: staticFiles)
        }

        serverTask = Task {
            do {
                try await http.run()
            } catch {
                print("JukeboxServer stopped: \(error)")
            }
        }

        try await http.waitUntilListening()
        publishBonjourService(port: port)
    }

    public func stop() async {
        bonjourService?.stop()
        bonjourService = nil
        serverTask?.cancel()
        serverTask = nil
        await server?.stop()
        server = nil
    }

    public var clientCount: Int {
        wsHandler.clientCount
    }

    private func jsonResponse<T: Encodable>(_ value: T, status: HTTPStatusCode = .ok) async throws -> HTTPResponse {
        let data = try encoder.encode(value)
        var headers = HTTPHeaders()
        headers.addValue("application/json", for: .contentType)
        headers.addValue("*", for: HTTPHeader("Access-Control-Allow-Origin"))
        return HTTPResponse(statusCode: status, headers: headers, body: data)
    }

    private func makeStatus(port: UInt16) async -> HostServerStatus {
        HostServerStatus(
            hostIP: Self.localIPAddress() ?? "127.0.0.1",
            port: Int(port),
            connectedClients: clientCount,
            wifiConnected: Self.localIPAddress() != nil
        )
    }

    private static func baseURL(for request: HTTPRequest, port: UInt16) -> String {
        if let host = request.headers[.host], !host.isEmpty {
            return "http://\(host)"
        }
        let ip = Self.localIPAddress() ?? "127.0.0.1"
        return "http://\(ip):\(port)"
    }

    private static func participant(from request: HTTPRequest) -> String? {
        guard let value = request.query.first(where: { $0.name == "participant" })?.value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func publishBonjourService(port: UInt16) {
        let service = NetService(
            domain: "local.",
            type: "_jukebox._tcp.",
            name: "Jukebox",
            port: Int32(port)
        )
        service.publish()
        bonjourService = service
    }

    public static func localIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let family = interface.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name.hasPrefix("en") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    let ip = String(cString: hostname)
                    if !ip.hasPrefix("127.") {
                        address = ip
                    }
                }
            }
        }
        return address
    }
}

private struct StaticWebFilesHandler: HTTPHandler {
    let root: URL

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        let trimmed = request.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let relativePath = trimmed.isEmpty ? "index.html" : trimmed

        guard !relativePath.contains("..") else {
            return HTTPResponse(statusCode: .badRequest)
        }

        let fileURL = root.appendingPathComponent(relativePath)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              let data = try? Data(contentsOf: fileURL) else {
            return HTTPResponse(statusCode: .notFound)
        }

        var headers = HTTPHeaders()
        headers[.contentType] = contentType(for: fileURL.pathExtension)
        return HTTPResponse(statusCode: .ok, headers: headers, body: data)
    }

    private func contentType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "js": return "application/javascript; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "png": return "image/png"
        case "svg": return "image/svg+xml"
        case "ico": return "image/x-icon"
        default: return "application/octet-stream"
        }
    }
}
