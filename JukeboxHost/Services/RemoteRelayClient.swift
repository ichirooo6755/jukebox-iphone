import Foundation
import JukeboxCore

/// ホストがリレーサーバーへアウトバウンド接続し、リモート参加者の API をローカル JukeboxServer へ転送する。
@MainActor
final class RemoteRelayClient: ObservableObject {
    @Published private(set) var joinCode: String?
    @Published private(set) var joinURL: String?
    @Published private(set) var proxyURL: String?
    @Published private(set) var isConnected = false
    @Published private(set) var lastError: String?

    private static let roomIDKey = "jukebox_relay_room_id"
    private static let hostSecretKey = "jukebox_relay_host_secret"
    private static let joinCodeKey = "jukebox_relay_join_code"

    private var relayBaseURL: URL?
    private var roomID: String?
    private var hostSecret: String?
    private var localPort: UInt16 = JukeboxServer.defaultPort
    private var socketTask: Task<Void, Never>?
    private var statePushTask: Task<Void, Never>?
    private var webSocket: URLSessionWebSocketTask?
    private var stateProvider: (() async -> NowPlayingState)?

    func configure(stateProvider: @escaping () async -> NowPlayingState) {
        self.stateProvider = stateProvider
    }

    func start(relayBaseURL: URL, localPort: UInt16 = JukeboxServer.defaultPort) async {
        stop()
        self.relayBaseURL = relayBaseURL
        self.localPort = localPort
        lastError = nil

        do {
            try await registerOrReconnect()
            connectWebSocket()
            startStatePush()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stop() {
        socketTask?.cancel()
        statePushTask?.cancel()
        socketTask = nil
        statePushTask = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false
    }

    private func registerOrReconnect() async throws {
        guard let relayBaseURL else { return }

        let savedRoomID = UserDefaults.standard.string(forKey: Self.roomIDKey)
        let savedSecret = UserDefaults.standard.string(forKey: Self.hostSecretKey)
        let savedJoinCode = UserDefaults.standard.string(forKey: Self.joinCodeKey)

        var body: [String: String] = [:]
        if let savedRoomID, let savedSecret {
            body["room_id"] = savedRoomID
            body["host_secret"] = savedSecret
            if let savedJoinCode {
                body["join_code"] = savedJoinCode
            }
        }

        let url = relayBaseURL.appendingPathComponent("api/relay/rooms")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "登録失敗"
            throw NSError(domain: "RemoteRelay", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard
            let roomID = json?["room_id"] as? String,
            let hostSecret = json?["host_secret"] as? String,
            let joinCode = json?["join_code"] as? String
        else {
            throw NSError(domain: "RemoteRelay", code: 2, userInfo: [NSLocalizedDescriptionKey: "ルーム情報の解析に失敗"])
        }

        self.roomID = roomID
        self.hostSecret = hostSecret
        self.joinCode = joinCode
        self.joinURL = json?["join_url"] as? String
        self.proxyURL = json?["proxy_url"] as? String

        UserDefaults.standard.set(roomID, forKey: Self.roomIDKey)
        UserDefaults.standard.set(hostSecret, forKey: Self.hostSecretKey)
        UserDefaults.standard.set(joinCode, forKey: Self.joinCodeKey)
    }

    private func connectWebSocket() {
        guard
            let relayBaseURL,
            let roomID,
            let hostSecret
        else { return }

        var components = URLComponents(url: relayBaseURL, resolvingAgainstBaseURL: false)
        components?.scheme = relayBaseURL.scheme == "https" ? "wss" : "ws"
        components?.path = "/api/relay/host/ws"
        components?.queryItems = [
            URLQueryItem(name: "room_id", value: roomID),
            URLQueryItem(name: "secret", value: hostSecret),
        ]
        guard let wsURL = components?.url else { return }

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: wsURL)
        webSocket = task
        task.resume()

        socketTask = Task { [weak self] in
            await self?.receiveLoop(task: task)
        }
    }

    private func receiveLoop(task: URLSessionWebSocketTask) async {
        isConnected = true
        defer {
            isConnected = false
        }

        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                guard case .string(let text) = message,
                      let data = text.data(using: .utf8),
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      json["type"] as? String == "request",
                      let id = json["id"] as? String,
                      let method = json["method"] as? String,
                      let path = json["path"] as? String
                else { continue }

                let response = await forwardToLocal(
                    method: method,
                    path: path,
                    body: json["body"]
                )
                var payload: [String: Any] = [
                    "type": "response",
                    "id": id,
                    "status": response.status,
                ]
                if let body = response.body {
                    payload["body"] = body
                }
                if let headers = response.headers {
                    payload["headers"] = headers
                }
                let out = try JSONSerialization.data(withJSONObject: payload)
                try await task.send(.string(String(data: out, encoding: .utf8) ?? "{}"))
            } catch {
                if Task.isCancelled { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                connectWebSocket()
                return
            }
        }
    }

    private struct LocalResponse {
        let status: Int
        let body: Any?
        let headers: [String: String]?
    }

    private func forwardToLocal(method: String, path: String, body: Any?) async -> LocalResponse {
        guard let url = URL(string: "http://127.0.0.1:\(localPort)\(path)") else {
            return LocalResponse(status: 400, body: ["error": "invalid path"], headers: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30

        if let body {
            if JSONSerialization.isValidJSONObject(body) {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            } else if let text = body as? String {
                request.httpBody = Data(text.utf8)
            }
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            let status = http?.statusCode ?? 500
            let contentType = http?.value(forHTTPHeaderField: "Content-Type") ?? ""

            if contentType.contains("application/json"),
               let parsed = try? JSONSerialization.jsonObject(with: data) {
                return LocalResponse(status: status, body: parsed, headers: ["Content-Type": "application/json"])
            }
            if status == 204 {
                return LocalResponse(status: status, body: nil, headers: nil)
            }
            let text = String(data: data, encoding: .utf8) ?? ""
            return LocalResponse(status: status, body: text, headers: ["Content-Type": contentType])
        } catch {
            return LocalResponse(
                status: 502,
                body: ["error": error.localizedDescription],
                headers: ["Content-Type": "application/json"]
            )
        }
    }

    private func startStatePush() {
        statePushTask?.cancel()
        statePushTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pushStateIfPossible()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func pushStateIfPossible() async {
        guard let task = webSocket, isConnected, let stateProvider else { return }
        let state = await stateProvider()
        guard let data = try? JSONEncoder().encode(state),
              let object = try? JSONSerialization.jsonObject(with: data)
        else { return }

        let payload: [String: Any] = ["type": "state", "payload": object]
        guard let out = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: out, encoding: .utf8) else { return }
        try? await task.send(.string(text))
    }

    static func relayBaseURLFromEnvironment() -> URL? {
        if let value = ProcessInfo.processInfo.environment["RELAY_BASE_URL"],
           !value.isEmpty,
           let url = URL(string: value) {
            return url
        }
        #if DEBUG
        return URL(string: "http://127.0.0.1:8780")
        #else
        return nil
        #endif
    }
}
