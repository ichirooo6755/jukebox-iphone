import ActivityKit
import SwiftUI
import WidgetKit

@main
struct JukeboxGuestWidgetBundle: WidgetBundle {
    var body: some Widget {
        JukeboxGuestLiveActivity()
    }
}

struct JukeboxGuestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: JukeboxActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isPlaying ? "waveform" : "pause.circle")
                        .foregroundStyle(.pink)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.state.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.service)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        value: Double(context.state.elapsed),
                        total: Double(max(context.state.duration, 1))
                    )
                    .tint(.pink)
                    HStack {
                        Text("スキップ \(context.state.skipVotes)/\(context.state.skipRequired)")
                            .font(.caption2)
                        Spacer()
                        Text("キュー \(context.state.queueCount)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "music.note")
                    .foregroundStyle(.pink)
            } compactTrailing: {
                Image(systemName: context.state.isPlaying ? "play.fill" : "pause.fill")
            } minimal: {
                Image(systemName: "music.note")
                    .foregroundStyle(.pink)
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<JukeboxActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(context.attributes.hostLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(context.state.service)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(context.state.title)
                .font(.headline)
                .lineLimit(1)
            Text(context.state.artist)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            ProgressView(
                value: Double(context.state.elapsed),
                total: Double(max(context.state.duration, 1))
            )
            .tint(.pink)
            HStack {
                Label(
                    context.state.isPlaying ? "再生中" : "一時停止",
                    systemImage: context.state.isPlaying ? "play.fill" : "pause.fill"
                )
                .font(.caption)
                Spacer()
                Text("投票 \(context.state.skipVotes)/\(context.state.skipRequired)")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
