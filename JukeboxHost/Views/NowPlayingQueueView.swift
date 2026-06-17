import JukeboxCore
import SwiftUI

struct NowPlayingQueueView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let isWide = size.width >= 720 && size.width > size.height * 0.9
            let artworkSide = min(size.width * (isWide ? 0.38 : 0.78), size.height * (isWide ? 0.72 : 0.36), 440)
            let edge = max(20, min(size.width, size.height) * 0.04)
            let topInset: CGFloat = 56

            ZStack {
                ArtworkBackgroundView(artworkURL: model.playbackState.current?.artworkURL)

                if isWide {
                    HStack(spacing: edge) {
                        ZStack {
                            artworkView
                                .frame(width: artworkSide, height: artworkSide)
                        }
                        .frame(width: size.width * 0.44)
                        .frame(maxHeight: .infinity)

                        rightColumn(topInset: topInset, edge: edge, queueHeight: max(140, size.height - topInset - 180))
                    }
                    .padding(.leading, topInset)
                    .padding(.trailing, edge)
                    .padding(.vertical, edge)
                    .frame(width: size.width, height: size.height)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            artworkView
                                .frame(width: artworkSide, height: artworkSide)
                                .padding(.top, topInset)

                            rightColumn(topInset: 0, edge: edge, queueHeight: max(120, size.height * 0.28))
                        }
                        .padding(.horizontal, edge)
                        .padding(.bottom, edge)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(width: size.width, height: size.height)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func rightColumn(topInset: CGFloat, edge: CGFloat, queueHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if topInset > 0 {
                Spacer(minLength: 0)
            }

            trackHeader
            progressSection

            queueSection
                .frame(maxHeight: queueHeight)

            footerBar

            if topInset > 0 {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, topInset > 0 ? 8 : 0)
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
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(Image(systemName: "music.note").font(.system(size: 48)).foregroundColor(.white.opacity(0.3)))
    }

    private var trackHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.playbackState.current?.title ?? "再生待ち")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(model.playbackState.current?.artist ?? "キューに曲を追加")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

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
                        .frame(width: max(0, barGeo.size.width * progress), height: 4)
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

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("次の曲", systemImage: "list.bullet")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.6))

            if model.playbackState.queue.isEmpty {
                Text("キューは空です")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(model.playbackState.queue.prefix(8)) { item in
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
                                Spacer(minLength: 8)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
    }

    private var footerBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: model.playbackState.isPlaying ? "waveform" : "pause.circle")
                Text(model.playbackState.isPlaying ? "再生中" : "停止中")
                Spacer()
                Image(systemName: model.audioOutput.isHeadphoneConnected ? "headphones" : "speaker.wave.2.fill")
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.5))

            Text(model.audioOutput.routeDetail)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
