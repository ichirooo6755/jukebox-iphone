import Foundation

public protocol AppleMusicSearching: Sendable {
    func search(query: String) async -> [TrackSearchResult]
}

public actor SearchCoordinator {
    public static let shared = SearchCoordinator()

    private var appleMusicSearcher: (any AppleMusicSearching)?

    public func setAppleMusicSearcher(_ searcher: (any AppleMusicSearching)?) {
        appleMusicSearcher = searcher
    }

    public func search(query: String, service: MusicService) async -> [TrackSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        switch service {
        case .appleMusic:
            return await appleMusicSearcher?.search(query: trimmed) ?? []
        case .spotify:
            return await SpotifySearchService.shared.search(query: trimmed)
        case .youtube:
            return await YouTubeSearchService.shared.search(query: trimmed)
        }
    }
}
