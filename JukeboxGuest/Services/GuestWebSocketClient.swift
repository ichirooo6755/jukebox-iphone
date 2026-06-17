import Foundation
import JukeboxCore

@MainActor
final class GuestWebSocketClient: ObservableObject {
    @Published private(set) var isConnected = false

    var onEvent: ((JukeboxEvent) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?

    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var activeBaseURL: String?
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func connect(baseURL: String) {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else {
            disconnect()
            return
        }
        if activeBaseURL == trimmed, isConnected { return }
        activeBaseURL = trimmed
        openSocket()
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        activeBaseURL = nil
        setConnected(false)
    }

    private func openSocket() {
        receiveTask?.cancel()
        task?.cancel(with: .goingAway, reason: nil)

        guard let activeBaseURL,
              let url = URL(string: activeBaseURL.replacingOccurrences(of: "https://", with: "wss://")
                .replacingOccurrences(of: "http://", with: "ws://") + "/ws") else {
            setConnected(false)
            return
        }

        task = URLSession.shared.webSocketTask(with: url)
        task?.resume()
        receiveTask = Task { await receiveLoop() }
    }

    private func receiveLoop() async {
        guard let task else { return }
        setConnected(true)

        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    handle(text: text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handle(text: text)
                    }
                @unknown default:
                    break
                }
            } catch {
                setConnected(false)
                scheduleReconnect()
                return
            }
        }
    }

    private func handle(text: String) {
        guard let data = text.data(using: .utf8),
              let event = try? decoder.decode(JukeboxEvent.self, from: data) else { return }
        onEvent?(event)
    }

    private func scheduleReconnect() {
        guard activeBaseURL != nil else { return }
        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            openSocket()
        }
    }

    private func setConnected(_ value: Bool) {
        guard isConnected != value else { return }
        isConnected = value
        onConnectionChange?(value)
    }
}
