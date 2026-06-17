import ActivityKit
import Foundation
import JukeboxCore

@MainActor
final class GuestLiveActivityManager {
    static let shared = GuestLiveActivityManager()

    private var activity: Activity<JukeboxActivityAttributes>?

    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func sync(state: NowPlayingState, hostURL: String, nickname: String) {
        guard isSupported else { return }

        let current = state.current
        let title = current?.title ?? "待機中"
        let artist = current?.artist ?? "Jukebox"
        let service = current?.service.displayName ?? ""
        let duration = max(current?.duration ?? 0, 1)
        let hasVoted = state.skipVote.voters.contains(nickname)

        let content = JukeboxActivityAttributes.ContentState(
            title: title,
            artist: artist,
            service: service,
            isPlaying: state.isPlaying,
            elapsed: Int(state.elapsed),
            duration: duration,
            skipVotes: state.skipVote.votes,
            skipRequired: state.skipVote.required,
            hasVotedSkip: hasVoted,
            queueCount: state.queue.count
        )

        if let activity {
            Task {
                await activity.update(ActivityContent(state: content, staleDate: nil))
            }
            return
        }

        let hostLabel = URL(string: hostURL)?.host ?? "Jukebox"
        let attributes = JukeboxActivityAttributes(hostLabel: hostLabel)
        let contentState = ActivityContent(state: content, staleDate: nil)

        do {
            activity = try Activity.request(attributes: attributes, content: contentState)
        } catch {
            print("Live Activity start failed: \(error)")
        }
    }

    func end() {
        guard let activity else { return }
        let final = JukeboxActivityAttributes.ContentState(
            title: "切断しました",
            artist: "",
            service: "",
            isPlaying: false,
            elapsed: 0,
            duration: 1,
            skipVotes: 0,
            skipRequired: 2,
            hasVotedSkip: false,
            queueCount: 0
        )
        Task {
            await activity.end(ActivityContent(state: final, staleDate: nil), dismissalPolicy: .immediate)
        }
        self.activity = nil
    }
}
