import JukeboxCore
import SwiftUI

struct GuestRootView: View {
    @EnvironmentObject private var client: GuestAPIClient

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                GuestHomeView()
                    .tabItem { Label("ホーム", systemImage: "music.note.house.fill") }
                GuestSearchView()
                    .tabItem { Label("検索", systemImage: "magnifyingglass") }
                GuestQueueView()
                    .tabItem { Label("キュー", systemImage: "music.note.list") }
                GuestAccountView()
                    .tabItem { Label("アカウント", systemImage: "person.crop.circle") }
            }
            .tint(.pink)

            GuestToastOverlay(message: client.toastMessage)
                .animation(.easeInOut, value: client.toastMessage)
        }
        .sheet(isPresented: $client.showOnboarding) {
            GuestOnboardingSheet()
                .interactiveDismissDisabled()
        }
        .task {
            if !client.hostURL.isEmpty {
                try? await client.ensureParticipant()
                await client.refreshState()
                client.reconnectTransport()
            }
        }
    }
}

struct GuestOnboardingSheet: View {
    @EnvironmentObject private var client: GuestAPIClient
    @State private var name = ""
    @State private var host = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.house.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.pink.gradient)
                        Text("Jukebox に参加")
                            .font(.title2.bold())
                        Text("ホストの QR または URL を入力して参加できます")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section("接続") {
                    TextField("ホスト URL", text: $host)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Button("ホストを探す") {
                        Task { await client.discoverHosts() }
                    }
                    ForEach(client.discoveredHosts) { item in
                        Button(item.url) {
                            host = item.url
                        }
                        .font(.caption.monospaced())
                    }
                }

                Section("参加者") {
                    TextField("ニックネーム（任意）", text: $name)
                }

                Section {
                    Button("参加する") {
                        Task {
                            if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                try? await client.registerNickname(name)
                            }
                            if !host.isEmpty {
                                await client.connectToHost(host)
                            } else {
                                client.showOnboarding = false
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                }
            }
            .navigationTitle("ようこそ")
        }
    }
}
