import Foundation
import JukeboxCore
import MusicKit
import WebKit

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class PlaybackEngine: PlaybackControlling {
    private let musicPlayer = ApplicationMusicPlayer.shared
    private var youtubeWebView: WKWebView?
    #if os(iOS)
    private var youtubeWindow: UIWindow?
    #endif
    #if os(macOS)
    private var youtubeWindow: NSWindow?
    #endif
    private var trackFinishedTask: Task<Void, Never>?
    private(set) var elapsed: Double = 0
    private(set) var isPlaying = false
    private var currentItem: QueueItem?
    private var startDate: Date?
    private var pausedElapsed: Double = 0

    var onTrackFinished: (() -> Void)?
    var onLevelsUpdate: (([CGFloat]) -> Void)?

    nonisolated func currentElapsed() async -> Double {
        await MainActor.run { elapsed }
    }

    nonisolated func currentIsPlaying() async -> Bool {
        await MainActor.run { isPlaying }
    }

    func prepareCrossfade() async {
        isPlaying = false
        musicPlayer.pause()
        youtubeWebView?.evaluateJavaScript("player.pauseVideo();", completionHandler: nil)
        try? await Task.sleep(nanoseconds: 300_000_000)
    }

    func play(item: QueueItem) async throws {
        currentItem = item
        pausedElapsed = 0
        startDate = Date()
        isPlaying = true

        switch item.service {
        case .appleMusic:
            youtubeWebView = nil
            #if os(iOS)
            youtubeWindow?.isHidden = true
            youtubeWindow = nil
            #endif
            #if os(macOS)
            youtubeWindow?.close()
            youtubeWindow = nil
            #endif
            try await playAppleMusic(item: item)
            observeAppleMusicProgress()
        case .spotify:
            try await playSpotify(item: item)
            observeTimedProgress(duration: item.duration)
        case .youtube:
            try await playYouTube(item: item)
            observeYouTubeWatchdog(duration: max(item.duration, 180))
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
        onTrackFinished?()
    }

    private func playAppleMusic(item: QueueItem) async throws {
        let catalogRequest = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(item.musicID))
        let catalogResponse = try? await catalogRequest.response()
        if let song = catalogResponse?.items.first {
            musicPlayer.queue = ApplicationMusicPlayer.Queue(for: [song], startingAt: song)
            try await musicPlayer.play()
            return
        }

        var libraryRequest = MusicLibraryRequest<Song>()
        libraryRequest.filter(matching: \.id, equalTo: MusicItemID(item.musicID))
        let libraryResponse = try await libraryRequest.response()
        guard let song = libraryResponse.items.first else {
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
        PlatformOpenURL.open(url)
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
        var progressTimer;
        function postProgress() {
          if (!player || !player.getCurrentTime) return;
          window.webkit.messageHandlers.trackProgress.postMessage(String(player.getCurrentTime()));
        }
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            height: '1', width: '1', videoId: '\(item.musicID)',
            playerVars: { autoplay: 1, playsinline: 1, controls: 0, rel: 0 },
            events: {
              'onReady': function() {
                player.playVideo();
                progressTimer = setInterval(postProgress, 1000);
              },
              'onStateChange': function(e) {
                if (e.data === YT.PlayerState.ENDED) {
                  clearInterval(progressTimer);
                  window.webkit.messageHandlers.trackEnded.postMessage('ended');
                }
                if (e.data === YT.PlayerState.PLAYING) postProgress();
              },
              'onError': function() {
                window.webkit.messageHandlers.trackError.postMessage('error');
              }
            }
          });
        }
        </script></body></html>
        """
        let config = WKWebViewConfiguration()
        let endedHandler = YouTubeMessageHandler { [weak self] in
            Task { @MainActor in self?.onTrackFinished?() }
        }
        let progressHandler = YouTubeProgressHandler { [weak self] seconds in
            Task { @MainActor in
                self?.elapsed = seconds
                self?.emitVisualizerLevels()
            }
        }
        let errorHandler = YouTubeMessageHandler { [weak self] in
            Task { @MainActor in
                guard let self, self.currentItem?.musicID == item.musicID else { return }
                self.isPlaying = false
                DurabilityLog.record("youtube_embed_error:\(item.musicID)")
            }
        }
        config.userContentController.add(endedHandler, name: "trackEnded")
        config.userContentController.add(progressHandler, name: "trackProgress")
        config.userContentController.add(errorHandler, name: "trackError")
        let webView = WKWebView(frame: .zero, configuration: config)
        youtubeWebView = webView
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))

        #if os(iOS)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            throw PlaybackError.unsupported
        }
        let viewController = UIViewController()
        viewController.view = webView
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        window.rootViewController = viewController
        window.windowLevel = .normal
        window.alpha = 0.01
        window.isHidden = false
        youtubeWindow = window
        #endif

        #if os(macOS)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.isOpaque = false
        window.alphaValue = 0.01
        window.level = .normal
        window.orderBack(nil)
        youtubeWindow = window
        #endif
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
                emitVisualizerLevels()
                if state.playbackStatus == .stopped, currentItem != nil {
                    onTrackFinished?()
                    break
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func observeYouTubeWatchdog(duration: Int) {
        trackFinishedTask?.cancel()
        trackFinishedTask = Task {
            let total = Double(duration)
            try? await Task.sleep(nanoseconds: UInt64(total + 30) * 1_000_000_000)
            if !Task.isCancelled, isPlaying, currentItem?.service == .youtube {
                onTrackFinished?()
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
                    emitVisualizerLevels()
                    if elapsed >= total {
                        onTrackFinished?()
                        break
                    }
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func emitVisualizerLevels() {
        guard isPlaying else { return }
        let levels = (0..<32).map { i -> CGFloat in
            let base = sin(elapsed * 2.0 + Double(i) * 0.4) * 0.3 + 0.5
            let noise = CGFloat.random(in: 0...0.25)
            return CGFloat(min(1.0, max(0.08, base))) + noise * 0.3
        }
        onLevelsUpdate?(levels)
    }
}

private final class YouTubeMessageHandler: NSObject, WKScriptMessageHandler {
    private let onMessage: () -> Void
    init(onMessage: @escaping () -> Void) { self.onMessage = onMessage }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        onMessage()
    }
}

private final class YouTubeProgressHandler: NSObject, WKScriptMessageHandler {
    private let onProgress: (Double) -> Void
    init(onProgress: @escaping (Double) -> Void) { self.onProgress = onProgress }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let text = message.body as? String, let value = Double(text) {
            onProgress(value)
        }
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
