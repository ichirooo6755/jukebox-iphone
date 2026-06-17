import JukeboxCore
import SwiftUI

struct GuestHomeView: View {
    @EnvironmentObject private var client: GuestAPIClient

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    nowPlayingCard
                    playbackModeSection
                    if client.playbackState.playbackMode == .playlistRoulette {
                        GuestPlaylistGraphView(
                            playbackMode: client.playbackState.playbackMode,
                            lanes: client.playbackState.playlistLanes,
                            lastWinner: client.playbackState.lastRouletteParticipant,
                            sessionStartedAt: client.playbackState.sessionStartedAt
                        )
                    }
                    controlsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("いま再生中")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    GuestConnectionBadge(isConnected: client.isConnected)
                }
            }
            .refreshable { await client.refreshState() }
        }
    }

    private var nowPlayingCard: some View {
        VStack(spacing: 16) {
            artwork
            VStack(spacing: 6) {
                Text(client.playbackState.current?.title ?? "待機中")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(client.playbackState.current?.artist ?? "キューに曲を追加してください")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                if let service = client.playbackState.current?.service {
                    Text(service.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }
            }

            if let current = client.playbackState.current, current.duration > 0 {
                VStack(spacing: 6) {
                    ProgressView(value: client.playbackState.elapsed, total: Double(current.duration))
                        .tint(.pink)
                    HStack {
                        Text(guestFormatTime(client.playbackState.elapsed))
                        Spacer()
                        Text(guestFormatTime(Double(current.duration)))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    @ViewBuilder
    private var artwork: some View {
        Group {
            if let url = GuestArtworkURL.imageURL(for: client.playbackState.current, baseURL: client.hostURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 220, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
    }

    private var artworkPlaceholder: some View {
        ZStack {
            LinearGradient(colors: [.pink.opacity(0.5), .purple.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "music.note")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var playbackModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("再生モード")
                .font(.headline)
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var controlsSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 28) {
                Button {
                    Task { await client.togglePlayback() }
                } label: {
                    Image(systemName: client.playbackState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.pink, .primary.opacity(0.15))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await client.skipTrack() }
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 28))
                        .frame(width: 52, height: 52)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
            }

            let vote = client.playbackState.skipVote
            let hasVoted = vote.voters.contains(client.nickname)
            Button {
                Task { await client.voteSkip() }
            } label: {
                Label("スキップ投票 \(vote.votes)/\(vote.required)", systemImage: hasVoted ? "checkmark.circle.fill" : "hand.thumbsup")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(hasVoted ? .green : .pink)
            .disabled(hasVoted)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
