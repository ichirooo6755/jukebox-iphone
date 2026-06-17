import ActivityKit
import Foundation
import JukeboxCore

@MainActor
final class GuestLiveActivityManager {
    static let shared = GuestLiveActivityManager()

    private var activity: Activity<JukeboxActivityAttributes>?
    private var lastContent: JukeboxActivityAttributes.ContentState?
    private var lastProgressSecond = -1

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
        let elapsed = Int(state.elapsed)
        let hasVoted = state.skipVote.voters.contains(nickname)

        let content = JukeboxActivityAttributes.ContentState(
            title: title,
            artist: artist,
            service: service,
            isPlaying: state.isPlaying,
            elapsed: elapsed,
            duration: duration,
            skipVotes: state.skipVote.votes,
            skipRequired: state.skipVote.required,
            hasVotedSkip: hasVoted,
            queueCount: state.queue.count
        )

        if let lastContent, !shouldUpdate(from: lastContent, to: content, elapsed: elapsed) {
            return
        }

        lastContent = content
        lastProgressSecond = elapsed

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
        lastContent = nil
        lastProgressSecond = -1
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

    private func shouldUpdate(
        from previous: JukeboxActivityAttributes.ContentState,
        to next: JukeboxActivityAttributes.ContentState,
        elapsed: Int
    ) -> Bool {
        if previous.title != next.title { return true }
        if previous.artist != next.artist { return true }
        if previous.service != next.service { return true }
        if previous.isPlaying != next.isPlaying { return true }
        if previous.skipVotes != next.skipVotes { return true }
        if previous.skipRequired != next.skipRequired { return true }
        if previous.hasVotedSkip != next.hasVotedSkip { return true }
        if previous.queueCount != next.queueCount { return true }
        if abs(elapsed - lastProgressSecond) >= 5 { return true }
        return false
    }
}
