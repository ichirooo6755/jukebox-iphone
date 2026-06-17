import ActivityKit
import Foundation

struct JukeboxActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var artist: String
        var service: String
        var isPlaying: Bool
        var elapsed: Int
        var duration: Int
        var skipVotes: Int
        var skipRequired: Int
        var hasVotedSkip: Bool
        var queueCount: Int
    }

    var hostLabel: String
}
