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
        let http = HTTPServer(port: port)
        server = http

        await http.appendRoute("GET /api/health") { _ in
            HTTPResponse(statusCode: .ok, body: Data("ok".utf8))
        }

        await http.appendRoute("GET /api/status") { [weak self] _ in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            let status = await self.makeStatus(port: port)
            return try await self.jsonResponse(status)
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

        await http.appendRoute("POST /api/users") { [weak self] (request: HTTPRequest) in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            let body = try await request.bodyData
            let req = try self.decoder.decode(NicknameRequest.self, from: body)
            let user = try await self.store.registerUser(nickname: req.nickname)
            return try await self.jsonResponse(user, status: .created)
        }

        await http.appendRoute("GET /api/search") { [weak self] (request: HTTPRequest) in
            guard let self else { return HTTPResponse(statusCode: .internalServerError) }
            let query = request.query.first(where: { $0.name == "q" })?.value ?? ""
            let serviceRaw = request.query.first(where: { $0.name == "service" })?.value ?? "apple_music"
            let service = MusicService(rawValue: serviceRaw) ?? .appleMusic
            let results = await SearchCoordinator.shared.search(query: query, service: service)
            return try await self.jsonResponse(results)
        }

        await http.appendRoute("GET /ws", to: .webSocket(wsHandler))

        if let webRoot {
            await http.appendRoute("GET /*", to: .directory(subPath: webRoot.path, serverPath: ""))
        }

        serverTask = Task {
            do {
                try await http.run()
            } catch {
                print("JukeboxServer stopped: \(error)")
            }
        }

        try await http.waitUntilListening()
    }

    public func stop() async {
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
