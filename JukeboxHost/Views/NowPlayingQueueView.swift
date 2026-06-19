import JukeboxCore
import SwiftUI

struct NowPlayingQueueView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let isWide = size.width >= 720 && size.width > size.height * 0.72
            let artworkSide = min(
                isWide ? size.height * 0.52 : size.width * 0.68,
                isWide ? size.width * 0.36 : size.height * 0.34,
                400
            )
            let edge = max(20, min(size.width, size.height) * 0.045)
            let chromeTop: CGFloat = 56
            let chromeBottom: CGFloat = 168
            let qrReserve: CGFloat = isWide ? 168 : 0

            ZStack {
                ArtworkBackgroundView(item: model.playbackState.current)

                if isWide {
                    HStack(alignment: .center, spacing: max(24, edge)) {
                        artworkColumn(side: artworkSide)
                            .frame(maxWidth: .infinity)

                        sideColumn(
                            queueHeight: max(140, size.height - chromeTop - chromeBottom - 120),
                            qrReserve: qrReserve
                        )
                        .frame(width: min(size.width * 0.42, 440))
                    }
                    .padding(.top, chromeTop)
                    .padding(.bottom, chromeBottom)
                    .padding(.leading, edge)
                    .padding(.trailing, edge + qrReserve * 0.35)
                    .frame(width: size.width, height: size.height)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            artworkColumn(side: artworkSide)
                                .padding(.top, chromeTop)

                            sideColumn(
                                queueHeight: max(120, size.height * 0.26),
                                qrReserve: 0
                            )
                        }
                        .padding(.horizontal, edge)
                        .padding(.bottom, chromeBottom)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(width: size.width, height: size.height)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func artworkColumn(side: CGFloat) -> some View {
        VStack(spacing: 14) {
            artworkView(side: side)
            progressSection
                .frame(width: side)
        }
        .frame(maxWidth: .infinity)
    }

    private func sideColumn(queueHeight: CGFloat, qrReserve: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            trackHeader

            queueSection
                .frame(maxHeight: queueHeight)

            if model.playbackState.playbackMode == .playlistRoulette {
                PlaylistGraphView(
                    playbackMode: model.playbackState.playbackMode,
                    lanes: model.playbackState.playlistLanes,
                    lastWinner: model.playbackState.lastRouletteParticipant,
                    sessionStartedAt: model.playbackState.sessionStartedAt
                )
            }

            Spacer(minLength: 0)

            footerBar
        }
        .padding(.trailing, qrReserve > 0 ? 4 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func artworkView(side: CGFloat) -> some View {
        Group {
            if let url = HostArtworkURL.imageURL(for: model.playbackState.current) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: side, height: side)
                            .clipped()
                    default:
                        artworkPlaceholder(side: side)
                    }
                }
            } else {
                artworkPlaceholder(side: side)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.5), radius: 32, y: 16)
        .id(model.playbackState.current?.musicID)
    }

    private func artworkPlaceholder(side: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: side, height: side)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: min(56, side * 0.24), weight: .light))
                    .foregroundStyle(.white.opacity(0.28))
            )
    }

    private var trackHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.playbackState.current?.title ?? "再生待ち")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(model.playbackState.current?.artist ?? "キューに曲を追加してください")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                if let service = model.playbackState.current?.service {
                    Text(service.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.14), in: Capsule())
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
    }

    private var progressSection: some View {
        let duration = Double(model.playbackState.current?.duration ?? 0)
        let elapsed = model.playbackState.elapsed
        let progress = duration > 0 ? min(1, elapsed / duration) : 0
        let remaining = max(0, duration - elapsed)

        return VStack(spacing: 8) {
            GeometryReader { barGeo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.95), Color.white.opacity(0.72)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, barGeo.size.width * progress))
                }
            }
            .frame(height: 5)

            HStack {
                Text(formatTime(elapsed))
                Spacer()
                if duration > 0 {
                    Text(formatTime(remaining))
                } else {
                    Text("—")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("次の曲", systemImage: "list.bullet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))

            if model.playbackState.queue.isEmpty {
                Text("キューは空です")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.32))
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(model.playbackState.queue.prefix(8)) { item in
                            HStack(spacing: 12) {
                                queueThumb(for: item)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text("\(item.artist) · \(item.addedBy)")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.42))
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                Text(item.service.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.32))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            skipVoteBar
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func queueThumb(for item: QueueItem) -> some View {
        if let imgURL = HostArtworkURL.imageURL(for: item) {
            AsyncImage(url: imgURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipped()
                default:
                    Color.white.opacity(0.1)
                        .frame(width: 40, height: 40)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var skipVoteBar: some View {
        let vote = model.playbackState.skipVote
        return HStack(spacing: 6) {
            Image(systemName: "forward.end.circle")
            Text("スキップ投票 \(vote.votes)/\(vote.required)")
                .font(.caption)
            Spacer()
        }
        .foregroundStyle(.white.opacity(0.4))
        .padding(.top, 4)
    }

    private var footerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: model.playbackState.isPlaying ? "waveform" : "pause.circle")
                Text(model.playbackState.isPlaying ? "再生中" : "停止中")
                Spacer()
                #if os(iOS)
                AudioRoutePickerView(tint: .white.withAlphaComponent(0.8))
                    .frame(width: 28, height: 28)
                #else
                AudioRoutePickerView()
                    .frame(width: 28, height: 28)
                #endif
                Image(systemName: model.audioOutput.isHeadphoneConnected ? "headphones" : "speaker.wave.2.fill")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.5))

            Text(model.audioOutput.routeDetail)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.38))

            VolumeSliderView()
                .frame(height: 24)
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
    let item: QueueItem?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                if let url = HostArtworkURL.imageURL(for: item) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                .blur(radius: 90)
                                .opacity(0.45)
                        }
                    }
                }

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.55),
                        Color.black.opacity(0.25),
                        Color.black.opacity(0.65)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
}
