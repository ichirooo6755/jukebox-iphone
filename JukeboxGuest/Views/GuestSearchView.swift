import JukeboxCore
import SwiftUI

struct GuestSearchView: View {
    @EnvironmentObject private var client: GuestAPIClient
    @StateObject private var appleMusic = GuestAppleMusicService()
    @State private var service: MusicService = .spotify
    @State private var query = ""
    @State private var playlistURL = ""
    @State private var searchType: SearchType = .tracks
    @State private var playlists: [PlaylistSummary] = []
    @State private var tracks: [TrackSearchResult] = []
    @State private var unifiedResults: [UnifiedSearchResult] = []
    @State private var isLoading = false

    private enum SearchType: String, CaseIterable {
        case tracks = "曲"
        case playlists = "プレイリスト"
    }

    var body: some View {
        NavigationStack {
            List {
                serviceSection
                if service == .appleMusic {
                    appleMusicSection
                    unifiedResultsSection
                } else {
                    searchInputSection
                    trackResultsSection
                    playlistResultsSection
                }
                urlImportSection
                if let error = client.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .listStyle(.insetGrouped)
            .navigationTitle("検索")
            .searchable(text: $query, prompt: searchPrompt)
            .onSubmit(of: .search) {
                Task { await runSearch() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("検索") { Task { await runSearch() } }
                }
            }
            .task {
                appleMusic.refreshAuthorization()
                await client.refreshAuth()
            }
            .overlay {
                if isLoading { ProgressView().controlSize(.large) }
            }
        }
    }

    private var searchPrompt: String {
        if service == .appleMusic { return "曲・アーティスト・プレイリスト" }
        return searchType == .playlists ? "プレイリスト名（空欄で自分の一覧）" : "曲名・アーティスト"
    }

    private var serviceSection: some View {
        Section {
            Picker("サービス", selection: $service) {
                Text("Spotify").tag(MusicService.spotify)
                Text("YouTube").tag(MusicService.youtube)
                Text("Apple Music").tag(MusicService.appleMusic)
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .onChange(of: service) { _ in
                playlists = []
                tracks = []
                unifiedResults = []
            }
        }
    }

    private var appleMusicSection: some View {
        Section("Apple Music（この端末）") {
            Text("マイライブラリのプレイリストはこの iPhone の許可で読み取り、ホストで再生します。")
                .font(.caption)
                .foregroundStyle(.secondary)
            if appleMusic.isAuthorized {
                Label("許可済み", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("マイプレイリストを読み込む") {
                    Task { await loadAppleMusicPlaylists() }
                }
            } else {
                Button("Apple Music を許可") {
                    Task {
                        _ = await appleMusic.requestAuthorization()
                        if appleMusic.isAuthorized {
                            await loadAppleMusicPlaylists()
                        }
                    }
                }
            }
        }
    }

    private var searchInputSection: some View {
        Section {
            Picker("種類", selection: $searchType) {
                ForEach(SearchType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if searchType == .playlists {
                Button {
                    query = ""
                    Task { await runSearch() }
                } label: {
                    Label("自分のプレイリストを表示", systemImage: "person.crop.circle")
                }
            }
        }
    }

    @ViewBuilder
    private var unifiedResultsSection: some View {
        if !playlists.isEmpty {
            Section("マイプレイリスト") {
                ForEach(playlists, id: \.id) { playlist in
                    playlistButton(playlist)
                }
            }
        }
        if !unifiedResults.isEmpty {
            Section("検索結果") {
                ForEach(unifiedResults) { result in
                    unifiedResultButton(result)
                }
            }
        }
    }

    @ViewBuilder
    private var trackResultsSection: some View {
        if searchType == .tracks, !tracks.isEmpty {
            Section("曲") {
                ForEach(tracks) { track in
                    Button {
                        Task {
                            do {
                                try await client.addToQueue(track: track)
                            } catch {
                                client.errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        trackRow(title: track.title, subtitle: track.artist, service: track.service)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var playlistResultsSection: some View {
        if searchType == .playlists, !playlists.isEmpty {
            Section("プレイリスト") {
                ForEach(playlists, id: \.id) { playlist in
                    playlistButton(playlist)
                }
            }
        }
    }

    private var urlImportSection: some View {
        Section("プレイリスト URL") {
            TextField("https://...", text: $playlistURL)
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
    }

    private func playlistButton(_ summary: PlaylistSummary) -> some View {
        Button {
            Task { await importPlaylist(summary) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.title).font(.headline)
                Text(summary.owner).font(.caption).foregroundStyle(.secondary)
                if let count = summary.trackCount {
                    Text("\(count) 曲").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func unifiedResultButton(_ result: UnifiedSearchResult) -> some View {
        Button {
            Task { await importUnified(result) }
        } label: {
            trackRow(title: result.title, subtitle: result.subtitle, service: result.service, kind: result.kind.rawValue)
        }
    }

    private func trackRow(title: String, subtitle: String, service: MusicService, kind: String? = nil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let kind {
                Text(kindLabel(kind))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            Text(service.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func kindLabel(_ kind: String) -> String {
        switch kind {
        case "track": return "曲"
        case "playlist": return "PL"
        case "artist": return "アーティスト"
        default: return kind
        }
    }

    private func runSearch() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if service == .appleMusic {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    unifiedResults = []
                } else {
                    unifiedResults = try await client.unifiedSearch(query: query)
                }
                return
            }

            if searchType == .playlists {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    playlists = try await client.myPlaylists(service: service)
                } else {
                    playlists = try await client.searchPlaylists(service: service, query: query)
                }
                tracks = []
            } else {
                tracks = try await client.searchTracks(query: query, service: service)
                playlists = []
            }
        } catch {
            client.errorMessage = error.localizedDescription
        }
    }

    private func loadAppleMusicPlaylists() async {
        isLoading = true
        defer { isLoading = false }
        playlists = await appleMusic.myPlaylists()
    }

    private func importPlaylist(_ summary: PlaylistSummary) async {
        isLoading = true
        defer { isLoading = false }
        do {
            if service == .appleMusic {
                let trackList = await appleMusic.playlistTracks(playlistID: summary.id)
                guard !trackList.isEmpty else {
                    client.errorMessage = "プレイリストに曲がありません"
                    return
                }
                try await client.importPlaylistTracks(
                    service: .appleMusic,
                    playlistTitle: summary.title,
                    playlistID: summary.id,
                    playlistArtworkURL: summary.artworkURL,
                    tracks: trackList
                )
            } else {
                try await client.importPlaylistSummary(summary)
            }
        } catch {
            client.errorMessage = error.localizedDescription
        }
    }

    private func importUnified(_ result: UnifiedSearchResult) async {
        isLoading = true
        defer { isLoading = false }
        do {
            switch result.kind {
            case .track:
                guard let musicID = result.musicID else { return }
                let track = TrackSearchResult(
                    title: result.title,
                    artist: result.subtitle,
                    artworkURL: result.artworkURL,
                    service: result.service,
                    musicID: musicID,
                    duration: result.duration ?? 0
                )
                try await client.addToQueue(track: track)
            case .playlist:
                let summary = PlaylistSummary(
                    id: result.id,
                    title: result.title,
                    owner: result.subtitle,
                    artworkURL: result.artworkURL,
                    service: result.service,
                    trackCount: result.trackCount
                )
                try await client.importPlaylistSummary(summary)
            case .artist:
                guard let musicID = result.musicID else { return }
                try await client.importArtist(service: result.service, artistID: musicID)
            }
        } catch {
            client.errorMessage = error.localizedDescription
        }
    }
}
