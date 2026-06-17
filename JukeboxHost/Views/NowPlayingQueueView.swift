import JukeboxCore
import SwiftUI

struct NowPlayingQueueView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > geo.size.height || hSize == .regular

            ZStack {
                ArtworkBackgroundView(artworkURL: model.playbackState.current?.artworkURL)

                if isWide {
                    landscapeLayout(geo: geo)
                } else {
                    portraitLayout(geo: geo)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Landscape (参考画像レイアウト)

    private func landscapeLayout(geo: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // 左: アルバムアート
            HStack(spacing: 0) {
                sideRail
                artworkView
                    .frame(width: geo.size.height * 0.72, height: geo.size.height * 0.72)
                    .padding(.leading, 8)
            }
            .frame(width: geo.size.width * 0.48)

            // 右: コントロール + キュー
            VStack(alignment: .leading, spacing: 0) {
                trackHeader
                    .padding(.top, 40)

                progressSection
                    .padding(.top, 20)

                playbackControls
                    .padding(.top, 28)

                VolumeSliderView()
                    .padding(.top, 20)
                    .padding(.trailing, 40)

                Spacer()

                queueSection
                    .frame(maxHeight: geo.size.height * 0.28)

                footerBar
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Portrait

    private func portraitLayout(geo: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            statusBar.padding(.top, 8)

            artworkView
                .frame(width: geo.size.width * 0.72, height: geo.size.width * 0.72)

            trackHeader
            progressSection.padding(.horizontal, 24)
            playbackControls
            VolumeSliderView().padding(.horizontal, 32)

            queueSection
                .frame(maxHeight: geo.size.height * 0.22)
                .padding(.horizontal, 16)

            footerBar.padding(.bottom, 12)
        }
        .padding(.top, 48)
    }

    // MARK: - Components

    private var sideRail: some View {
        VStack {
            Image(systemName: "airplayaudio")
                .foregroundColor(.cyan)
                .font(.title3)
            Spacer()
            Image(systemName: model.audioOutput.isHeadphoneConnected ? "headphones" : "speaker.wave.2")
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 10)
        .frame(width: 44)
        .background(Color.black.opacity(0.65), in: Capsule())
        .padding(.leading, 12)
    }

    private var artworkView: some View {
        Group {
            if let urlString = model.playbackState.current?.artworkURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    artworkPlaceholder
                }
            } else {
                artworkPlaceholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
        .id(model.playbackState.current?.musicID)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(Image(systemName: "music.note").font(.system(size: 48)).foregroundColor(.white.opacity(0.3)))
    }

    private var trackHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.playbackState.current?.title ?? "再生待ち")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text(model.playbackState.current?.artist ?? "キューに曲を追加")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.65))
            }
            Spacer()
            if let service = model.playbackState.current?.service {
                Text(service.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12), in: Capsule())
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    private var progressSection: some View {
        let duration = Double(model.playbackState.current?.duration ?? 0)
        let elapsed = model.playbackState.elapsed
        let progress = duration > 0 ? min(1, elapsed / duration) : 0
        let remaining = max(0, duration - elapsed)

        return VStack(spacing: 6) {
            GeometryReader { barGeo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15)).frame(height: 4)
                    Capsule().fill(Color.white.opacity(0.85))
                        .frame(width: barGeo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)

            HStack {
                Text(formatTime(elapsed))
                Spacer()
                Text("-\(formatTime(remaining))")
            }
            .font(.caption.monospacedDigit())
            .foregroundColor(.white.opacity(0.55))
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 48) {
            Button { Task { await model.skip() } } label: {
                Image(systemName: "backward.fill").font(.title)
            }
            Button { Task { await model.togglePlayback() } } label: {
                Image(systemName: model.playbackState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 44))
            }
            Button { Task { await model.skip() } } label: {
                Image(systemName: "forward.fill").font(.title)
            }
        }
        .foregroundColor(.white)
    }

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("次の曲", systemImage: "list.bullet")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.6))

            if model.playbackState.queue.isEmpty {
                Text("キューは空です")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.35))
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(model.playbackState.queue.prefix(5)) { item in
                            HStack(spacing: 10) {
                                if let url = item.artworkURL, let imgURL = URL(string: url) {
                                    AsyncImage(url: imgURL) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Color.white.opacity(0.1)
                                    }
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text("\(item.artist) · \(item.addedBy)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.45))
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(item.service.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.35))
                            }
                        }
                    }
                }
            }

            skipVoteBar
        }
    }

    private var skipVoteBar: some View {
        let vote = model.playbackState.skipVote
        return HStack {
            Image(systemName: "forward.end.circle")
            Text("スキップ投票 \(vote.votes)/\(vote.required)")
                .font(.caption)
            Spacer()
        }
        .foregroundColor(.white.opacity(0.45))
        .padding(.top, 4)
    }

    private var statusBar: some View {
        HStack {
            if let status = model.serverStatus {
                Label(status.hostIP, systemImage: status.wifiConnected ? "wifi" : "wifi.slash")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var footerBar: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "quote.bubble")
                Spacer()
                Image(systemName: model.audioOutput.isHeadphoneConnected ? "headphones" : "speaker.wave.2.fill")
                Spacer()
                Image(systemName: "list.bullet")
            }
            .font(.title3)
            .foregroundColor(.white.opacity(0.5))
            .padding(.horizontal, 40)

            Text(model.audioOutput.routeDetail)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Background

struct ArtworkBackgroundView: View {
    let artworkURL: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.28),
                    Color(red: 0.04, green: 0.06, blue: 0.14),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let urlString = artworkURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                        .blur(radius: 80)
                        .opacity(0.35)
                } placeholder: { EmptyView() }
            }
        }
        .ignoresSafeArea()
    }
}
