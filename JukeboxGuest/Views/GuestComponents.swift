import JukeboxCore
import SwiftUI

struct GuestPlaylistGraphView: View {
    let playbackMode: QueuePlaybackMode
    let lanes: [PlaylistLane]
    let lastWinner: String?
    let sessionStartedAt: Date?

    private var sortedLanes: [PlaylistLane] {
        lanes.sorted { $0.joinedAt < $1.joinedAt }
    }

    private var sessionStart: Date {
        sessionStartedAt ?? sortedLanes.first?.joinedAt ?? Date()
    }

    var body: some View {
        if playbackMode != .playlistRoulette {
            EmptyView()
        } else if lanes.isEmpty {
            Text("プレイリストルーレット待機中")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("プレイリストルーレット", systemImage: "arrow.triangle.branch")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(lanes.filter(\.isActive).count) 人参加")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(sortedLanes) { lane in
                            laneCard(lane)
                        }
                    }
                }
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder
    private func laneCard(_ lane: PlaylistLane) -> some View {
        let isBranch = lane.joinedAt.timeIntervalSince(sessionStart) > 3
        let isWinner = lastWinner == lane.participant

        VStack(alignment: .leading, spacing: 8) {
            if isBranch {
                Label("途中参加", systemImage: "arrow.triangle.merge")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            Text(lane.displayName ?? lane.participant)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(lane.playlistTitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            ProgressView(value: Double(lane.position), total: Double(max(lane.tracks.count, 1)))
                .tint(isWinner ? .pink : .secondary)
            Text("\(lane.position)/\(lane.tracks.count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(width: 140, alignment: .leading)
        .padding(10)
        .background(isWinner ? Color.pink.opacity(0.15) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            if isWinner {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.pink.opacity(0.5), lineWidth: 1)
            }
        }
    }
}

struct GuestConnectionBadge: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(isConnected ? "接続中" : "再接続中…")
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct GuestToastOverlay: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(radius: 8, y: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
        }
    }
}

func guestFormatTime(_ sec: Double) -> String {
    let s = max(0, Int(sec))
    return String(format: "%d:%02d", s / 60, s % 60)
}
