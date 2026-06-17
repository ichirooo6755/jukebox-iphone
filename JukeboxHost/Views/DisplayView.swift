import SwiftUI

struct DisplayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            Spacer(minLength: 16)

            artworkSection
            trackInfoSection
            progressSection

            Spacer(minLength: 24)

            nextQueueSection

            Spacer(minLength: 16)

            controlBar
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color(white: 0.08), Color(white: 0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var statusBar: some View {
        HStack {
            if let status = model.serverStatus {
                Label(status.hostIP, systemImage: status.wifiConnected ? "wifi" : "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("参加者 \(status.connectedClients)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var artworkSection: some View {
        Group {
            if let urlString = model.playbackState.current?.artworkURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    artworkPlaceholder
                }
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 280, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.ultraThinMaterial)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
            }
    }

    private var trackInfoSection: some View {
        VStack(spacing: 6) {
            Text(model.playbackState.current?.title ?? "再生待ち")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(model.playbackState.current?.artist ?? "キューに曲を追加してください")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let service = model.playbackState.current?.service {
                Text(service.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.pink.opacity(0.2), in: Capsule())
                    .foregroundStyle(.pink)
            }
        }
        .padding(.top, 20)
    }

    private var progressSection: some View {
        let duration = Double(model.playbackState.current?.duration ?? 0)
        let elapsed = model.playbackState.elapsed
        let progress = duration > 0 ? min(1, elapsed / duration) : 0

        return VStack(spacing: 6) {
            ProgressView(value: progress)
                .tint(.pink)
            HStack {
                Text(formatTime(elapsed))
                Spacer()
                Text(formatTime(duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }

    private var nextQueueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Next")
                .font(.headline)
                .foregroundStyle(.secondary)

            if model.playbackState.queue.isEmpty {
                Text("キューは空です")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(model.playbackState.queue.prefix(5)) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text("\(item.service.displayName) · \(item.addedBy)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var controlBar: some View {
        HStack(spacing: 32) {
            Button {
                Task { await model.togglePlayback() }
            } label: {
                Image(systemName: model.playbackState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 52))
            }

            Button {
                Task { await model.skip() }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 36))
            }
        }
        .foregroundStyle(.white)
        .padding(.bottom, 8)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
