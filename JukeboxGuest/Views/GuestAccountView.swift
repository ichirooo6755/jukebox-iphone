import JukeboxCore
import SwiftUI

struct GuestAccountView: View {
    @EnvironmentObject private var client: GuestAPIClient
    @State private var nicknameDraft = ""

    var body: some View {
        NavigationStack {
            List {
                connectionSection
                participantSection
                discoverySection
                metricsSection
                servicesSection
                liveActivitySection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("アカウント")
            .task {
                nicknameDraft = client.nickname
                await client.refreshAuth()
            }
        }
    }

    private var connectionSection: some View {
        Section("接続") {
            TextField("http://192.168.x.x:8765", text: $client.hostURL)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .font(.body.monospaced())
            Button("接続") {
                Task { await client.connectToHost(client.hostURL) }
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            HStack {
                GuestConnectionBadge(isConnected: client.isConnected)
                Spacer()
                if client.playbackState.connectedClients > 0 {
                    Text("\(client.playbackState.connectedClients) 人接続")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var participantSection: some View {
        Section("参加者") {
            TextField("ニックネーム", text: $nicknameDraft)
            Button("名前を保存") {
                Task {
                    do {
                        try await client.registerNickname(nicknameDraft)
                        client.showToast("名前を保存しました")
                    } catch {
                        client.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private var discoverySection: some View {
        Section("ホストを探す") {
            Button {
                Task { await client.discoverHosts() }
            } label: {
                Label("同一 Wi-Fi のホストを検索", systemImage: "wifi")
            }
            ForEach(client.discoveredHosts) { host in
                Button {
                    Task { await client.connectToHost(host.url) }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(host.name ?? "Jukebox Host")
                            .font(.headline)
                        Text(host.url)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var metricsSection: some View {
        Section("同期") {
            Button("メトリクスを更新") {
                Task { await client.refreshMetrics() }
            }
            if let metrics = client.syncMetrics {
                if let roundTrip = metrics.roundTripMs {
                    LabeledContent("往復遅延", value: String(format: "%.0f ms", roundTrip))
                }
                if let clients = metrics.connectedClients {
                    LabeledContent("接続数", value: "\(clients)")
                }
            }
        }
    }

    private var servicesSection: some View {
        Section("サービス") {
            Text("Spotify / YouTube は参加者ごとにログイン。Apple Music は Search タブでこの端末を許可してください。")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(client.authStatuses, id: \.service) { status in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(status.service.displayName)
                        Spacer()
                        authBadge(status)
                    }
                    if let name = status.displayName {
                        Text(name).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func authBadge(_ status: ServiceAuthStatus) -> some View {
        if status.service == .appleMusic {
            Text("Search で許可")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if status.isAuthenticated {
            Label("OK", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        } else if status.loginURL != nil {
            Button("ログイン") {
                Task { await client.login(service: status.service) }
            }
            .font(.caption)
        } else {
            Text("未設定")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var liveActivitySection: some View {
        Section("ロック画面 / Dynamic Island") {
            Text("ホストに接続すると、再生中の曲がロック画面と Dynamic Island（対応機種）に表示されます。")
                .font(.caption)
                .foregroundStyle(.secondary)
            if GuestLiveActivityManager.shared.isSupported {
                Label("Live Activity 対応", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                Label("Live Activity が無効です（設定で許可してください）", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
    }
}
