import JukeboxCore
import SwiftUI

struct PlaylistGraphView: View {
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
                .foregroundStyle(.white.opacity(0.5))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("プレイリストルーレット")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(lanes.filter(\.isActive).count) 人参加")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(sortedLanes) { lane in
                            laneCard(lane)
                        }
                    }
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private func laneCard(_ lane: PlaylistLane) -> some View {
        let isBranch = lane.joinedAt.timeIntervalSince(sessionStart) > 3
        let isWinner = lastWinner == lane.participant

        VStack(alignment: .leading, spacing: 8) {
            if isBranch {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.merge")
                        .font(.caption2)
                    Text("途中参加")
                        .font(.caption2)
                }
                .foregroundStyle(.white.opacity(0.45))
            }

            HStack(spacing: 8) {
                avatar(for: lane)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lane.displayName ?? lane.participant)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(lane.playlistTitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lane.tracks.enumerated().prefix(6)), id: \.offset) { index, track in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(dotColor(for: lane, index: index))
                            .frame(width: 6, height: 6)
                        Text(track.title)
                            .font(.caption2)
                            .foregroundStyle(index == lane.position ? .white : .white.opacity(0.45))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.leading, 6)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color(hex: lane.color).opacity(0.5))
                    .frame(width: 2)
            }

            Text("\(lane.position)/\(lane.tracks.count)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(10)
        .frame(width: 180, alignment: .leading)
        .background(Color(hex: lane.color).opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(isWinner ? Color(hex: lane.color) : .white.opacity(0.08), lineWidth: isWinner ? 1.5 : 1)
        }
    }

    @ViewBuilder
    private func avatar(for lane: PlaylistLane) -> some View {
        if let url = lane.avatarURL.flatMap(URL.init(string:)) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                placeholderAvatar(lane)
            }
            .frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            placeholderAvatar(lane)
        }
    }

    private func placeholderAvatar(_ lane: PlaylistLane) -> some View {
        Text(String((lane.displayName ?? lane.participant).prefix(1)))
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(Color(hex: lane.color), in: RoundedRectangle(cornerRadius: 8))
    }

    private func dotColor(for lane: PlaylistLane, index: Int) -> Color {
        if index < lane.position { return .white.opacity(0.25) }
        if index == lane.position { return Color(hex: lane.color) }
        return .white.opacity(0.15)
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
