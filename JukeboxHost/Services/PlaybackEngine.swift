import Foundation
import JukeboxCore
import MediaPlayer
import MusicKit
import UIKit
import WebKit

@MainActor
final class PlaybackEngine: PlaybackControlling {
    private let musicPlayer = ApplicationMusicPlayer.shared
    private var youtubeWebView: WKWebView?
    private var trackFinishedTask: Task<Void, Never>?
    private(set) var elapsed: Double = 0
    private(set) var isPlaying = false
    private var currentItem: QueueItem?
    private var startDate: Date?
    private var pausedElapsed: Double = 0

    var onTrackFinished: (() -> Void)?

    nonisolated func currentElapsed() async -> Double {
        await MainActor.run { elapsed }
    }

    nonisolated func currentIsPlaying() async -> Bool {
        await MainActor.run { isPlaying }
    }

    func play(item: QueueItem) async throws {
        currentItem = item
        pausedElapsed = 0
        startDate = Date()
        isPlaying = true

        switch item.service {
        case .appleMusic:
            youtubeWebView = nil
            try await playAppleMusic(item: item)
            observeAppleMusicProgress()
        case .spotify:
            try await playSpotify(item: item)
            observeTimedProgress(duration: item.duration)
        case .youtube:
            try await playYouTube(item: item)
            observeTimedProgress(duration: max(item.duration, 180))
        }
    }

    func pause() async {
        isPlaying = false
        if let startDate {
            pausedElapsed += Date().timeIntervalSince(startDate)
        }
        startDate = nil
        musicPlayer.pause()
        youtubeWebView?.evaluateJavaScript("player.pauseVideo();", completionHandler: nil)
    }

    func resume() async {
        isPlaying = true
        startDate = Date()
        try? await musicPlayer.play()
        youtubeWebView?.evaluateJavaScript("player.playVideo();", completionHandler: nil)
    }

    func skip() async throws {
        trackFinishedTask?.cancel()
        if let onTrackFinished {
            onTrackFinished()
        }
    }

    private func playAppleMusic(item: QueueItem) async throws {
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(item.musicID))
        let response = try await request.response()
        guard let song = response.items.first else {
            throw PlaybackError.trackNotFound
        }
        musicPlayer.queue = ApplicationMusicPlayer.Queue(for: [song], startingAt: song)
        try await musicPlayer.play()
    }

    private func playSpotify(item: QueueItem) async throws {
        let spotifyURI = "spotify:track:\(item.musicID)"
        guard let url = URL(string: spotifyURI) else {
            throw PlaybackError.unsupported
        }
        await UIApplication.shared.open(url)
        observeTimedProgress(duration: max(item.duration, 180))
    }

    private func playYouTube(item: QueueItem) async throws {
        let html = """
        <!DOCTYPE html>
        <html><body style="margin:0;background:#000">
        <div id="player"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
        var player;
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            height: '1', width: '1', videoId: '\(item.musicID)',
            playerVars: { autoplay: 1, playsinline: 1 },
            events: { 'onStateChange': function(e) {
              if (e.data === YT.PlayerState.ENDED) {
                window.webkit.messageHandlers.trackEnded.postMessage('ended');
              }
            }}
          });
        }
        </script></body></html>
        """
        let config = WKWebViewConfiguration()
        let handler = YouTubeMessageHandler { [weak self] in
            Task { @MainActor in self?.onTrackFinished?() }
        }
        config.userContentController.add(handler, name: "trackEnded")
        let webView = WKWebView(frame: .zero, configuration: config)
        youtubeWebView = webView
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
    }

    private func observeAppleMusicProgress() {
        trackFinishedTask?.cancel()
        trackFinishedTask = Task {
            while !Task.isCancelled {
                let state = musicPlayer.state
                isPlaying = state.playbackStatus == .playing
                if let time = musicPlayer.playbackTime as Double? {
                    elapsed = time
                }
                if state.playbackStatus == .stopped, currentItem != nil {
                    onTrackFinished?()
                    break
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func observeTimedProgress(duration: Int) {
        trackFinishedTask?.cancel()
        trackFinishedTask = Task {
            let total = Double(duration)
            while !Task.isCancelled {
                if isPlaying, let startDate {
                    elapsed = min(total, pausedElapsed + Date().timeIntervalSince(startDate))
                    if elapsed >= total {
                        onTrackFinished?()
                        break
                    }
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
}

private final class YouTubeMessageHandler: NSObject, WKScriptMessageHandler {
    private let onEnded: () -> Void
    init(onEnded: @escaping () -> Void) { self.onEnded = onEnded }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        onEnded()
    }
}

enum PlaybackError: LocalizedError {
    case trackNotFound
    case unsupported

    var errorDescription: String? {
        switch self {
        case .trackNotFound: return "楽曲が見つかりませんでした"
        case .unsupported: return "このサービスは再生できません"
        }
    }
}
