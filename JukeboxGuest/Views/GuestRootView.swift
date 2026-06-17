import JukeboxCore
import SwiftUI

struct GuestRootView: View {
    @EnvironmentObject private var client: GuestAPIClient

    var body: some View {
        TabView {
            GuestHomeView()
                .tabItem { Label("Home", systemImage: "music.note.house") }
            GuestSearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            GuestAccountView()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .task {
            if !client.hostURL.isEmpty {
                await client.refreshState()
            }
        }
    }
}

struct GuestHomeView: View {
    @EnvironmentObject private var client: GuestAPIClient

    var body: some View {
        NavigationStack {
            List {
                if let current = client.playbackState.current {
                    Section("Now Playing") {
                        LabeledContent(current.title, value: current.artist)
                        LabeledContent("サービス", value: current.service.displayName)
                    }
                }
                Section("再生モード") {
                    Picker("モード", selection: Binding(
                        get: { client.playbackState.playbackMode },
                        set: { mode in Task { await client.setPlaybackMode(mode) } }
                    )) {
                        ForEach(QueuePlaybackMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if client.playbackState.playbackMode == .playlistRoulette {
                    Section("ルーレット") {
                        ForEach(client.playbackState.playlistLanes) { lane in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(lane.displayName ?? lane.participant)
                                    .font(.headline)
                                Text(lane.playlistTitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("\(lane.position)/\(lane.tracks.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Jukebox")
            .refreshable { await client.refreshState() }
        }
    }
}

struct GuestSearchView: View {
    @EnvironmentObject private var client: GuestAPIClient
    @State private var playlistURL = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("プレイリスト URL") {
                    TextField("https://open.spotify.com/playlist/...", text: $playlistURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Button("URL から追加") {
                        Task {
                            do {
                                try await client.importPlaylistURL(playlistURL)
                                playlistURL = ""
                            } catch {
                                client.errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
                if let error = client.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Search")
        }
    }
}

struct GuestAccountView: View {
    @EnvironmentObject private var client: GuestAPIClient

    var body: some View {
        NavigationStack {
            Form {
                Section("接続") {
                    TextField("ホスト URL", text: $client.hostURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Button("接続") {
                        Task {
                            await client.refreshState()
                            await client.refreshAuth()
                        }
                    }
                }
                Section("参加者") {
                    TextField("ニックネーム", text: $client.nickname)
                }
                Section("サービス") {
                    ForEach(client.authStatuses, id: \.service) { status in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(status.service.displayName)
                                Spacer()
                                if status.isAuthenticated {
                                    Text("OK").foregroundStyle(.green)
                                } else if status.service == .appleMusic {
                                    Text("ホスト共有").foregroundStyle(.secondary)
                                } else if status.loginURL != nil {
                                    Button("ログイン") {
                                        Task { await client.login(service: status.service) }
                                    }
                                } else {
                                    Text("未設定").foregroundStyle(.orange)
                                }
                            }
                            if let name = status.displayName {
                                Text(name).font(.caption).foregroundStyle(.secondary)
                            }
                            if !status.message.isEmpty {
                                Text(status.message).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Account")
            .task { await client.refreshAuth() }
        }
    }
}
