import Foundation

public struct ServerMetricsSnapshot: Codable, Sendable {
    public var uptimeSeconds: Double
    public var connectedClients: Int
    public var broadcastCount: Int
    public var lastBroadcastMsAgo: Double?
    public var serverStartedAt: Date

    enum CodingKeys: String, CodingKey {
        case uptimeSeconds = "uptime_seconds"
        case connectedClients = "connected_clients"
        case broadcastCount = "broadcast_count"
        case lastBroadcastMsAgo = "last_broadcast_ms_ago"
        case serverStartedAt = "server_started_at"
    }
}

public struct DurabilitySelfTestResult: Codable, Sendable {
    public var passed: Bool
    public var healthOK: Bool
    public var stateLatencyMs: Double
    public var websocketLatencyMs: Double?
    public var message: String

    enum CodingKeys: String, CodingKey {
        case passed
        case healthOK = "health_ok"
        case stateLatencyMs = "state_latency_ms"
        case websocketLatencyMs = "websocket_latency_ms"
        case message
    }
}

public struct HostDiscoverInfo: Codable, Sendable {
    public var name: String
    public var bonjourType: String
    public var hostname: String
    public var port: Int
    public var url: String

    enum CodingKeys: String, CodingKey {
        case name
        case bonjourType = "bonjour_type"
        case hostname
        case port
        case url
    }
}

public actor ServerMetrics {
    public static let shared = ServerMetrics()

    private let startedAt = Date()
    private var broadcastCount = 0
    private var lastBroadcastAt: Date?

    public func recordBroadcast() {
        broadcastCount += 1
        lastBroadcastAt = Date()
    }

    public func snapshot(connectedClients: Int) -> ServerMetricsSnapshot {
        let lastMs: Double?
        if let lastBroadcastAt {
            lastMs = Date().timeIntervalSince(lastBroadcastAt) * 1000
        } else {
            lastMs = nil
        }
        return ServerMetricsSnapshot(
            uptimeSeconds: Date().timeIntervalSince(startedAt),
            connectedClients: connectedClients,
            broadcastCount: broadcastCount,
            lastBroadcastMsAgo: lastMs,
            serverStartedAt: startedAt
        )
    }

    public func reset() {
        broadcastCount = 0
        lastBroadcastAt = nil
    }
}
