import JukeboxCore
import SwiftUI

struct HostDurabilitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var events: [String] = DurabilityLog.load()
    @State private var metrics: ServerMetricsSnapshot?
    @State private var selfTestResult: DurabilitySelfTestResult?
    @State private var isRunningTest = false
    @State private var errorMessage: String?

    private var baseURL: String {
        let ip = JukeboxServer.localIPAddress() ?? "127.0.0.1"
        return "http://\(ip):\(JukeboxServer.defaultPort)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("サーバーメトリクス") {
                    if let metrics {
                        LabeledContent("稼働時間", value: formatUptime(metrics.uptimeSeconds))
                        LabeledContent("接続クライアント", value: "\(metrics.connectedClients)")
                        LabeledContent("配信回数", value: "\(metrics.broadcastCount)")
                        if let lastMs = metrics.lastBroadcastMsAgo {
                            LabeledContent("最終配信", value: "\(Int(lastMs))ms 前")
                        }
                    } else {
                        Text("読み込み中…").foregroundStyle(.secondary)
                    }
                }

                Section("セルフテスト") {
                    if let result = selfTestResult {
                        LabeledContent("結果", value: result.passed ? "合格" : "不合格")
                        LabeledContent("状態取得", value: "\(Int(result.stateLatencyMs))ms")
                        Text(result.message).font(.caption).foregroundStyle(.secondary)
                    }
                    Button(isRunningTest ? "テスト実行中…" : "セルフテストを実行") {
                        Task { await runSelfTest() }
                    }
                    .disabled(isRunningTest)
                }

                Section("耐久ログ") {
                    if events.isEmpty {
                        Text("まだイベントはありません").foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(events.reversed().enumerated()), id: \.offset) { _, event in
                            Text(event).font(.caption.monospaced())
                        }
                    }
                    Button("ログを更新") { Task { await refresh() } }
                    Button("ログをクリア", role: .destructive) { Task { await clearLogs() } }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("耐久・メトリクス")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task { await refresh() }
        }
    }

    private func refresh() async {
        events = DurabilityLog.load()
        errorMessage = nil
        guard let url = URL(string: "\(baseURL)/api/metrics") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            metrics = try decoder.decode(ServerMetricsSnapshot.self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runSelfTest() async {
        isRunningTest = true
        defer { isRunningTest = false }
        guard let url = URL(string: "\(baseURL)/api/durability/self-test") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                errorMessage = "セルフテストに失敗しました"
                return
            }
            selfTestResult = try JSONDecoder().decode(DurabilitySelfTestResult.self, from: data)
            events = DurabilityLog.load()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearLogs() async {
        guard let url = URL(string: "\(baseURL)/api/durability/events") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try? await URLSession.shared.data(for: request)
        events = []
        await refresh()
    }

    private func formatUptime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
