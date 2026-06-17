import JukeboxCore
import SwiftUI

struct VisualizerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background

                VStack(spacing: 24) {
                    Spacer()

                    if let current = model.playbackState.current {
                        artwork(for: current)
                            .frame(width: min(geo.size.width * 0.5, 280))
                            .shadow(color: .black.opacity(0.5), radius: 30, y: 16)

                        VStack(spacing: 6) {
                            Text(current.title)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            Text(current.artist)
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal)
                    }

                    visualizerBars(width: geo.size.width * 0.85)
                        .frame(height: min(geo.size.height * 0.25, 180))

                    outputStatus
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.08, blue: 0.2),
                Color(red: 0.02, green: 0.02, blue: 0.08),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func artwork(for item: QueueItem) -> some View {
        Group {
            if let urlString = item.artworkURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    placeholderArt
                }
            } else {
                placeholderArt
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var placeholderArt: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(Image(systemName: "music.note").font(.largeTitle).foregroundColor(.white.opacity(0.4)))
    }

    private func visualizerBars(width: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(model.visualizerLevels.enumerated()), id: \.offset) { index, level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(
                        width: max(3, width / CGFloat(model.visualizerLevels.count) - 3),
                        height: max(8, level * 160)
                    )
                    .animation(.easeOut(duration: 0.12), value: level)
                    .opacity(model.playbackState.isPlaying ? 1 : 0.35)
            }
        }
    }

    private var outputStatus: some View {
        VStack(spacing: 4) {
            Text(model.audioOutput.statusLine)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            if let status = model.serverStatus {
                Text("Wi-Fi \(status.hostIP) · 参加者 \(status.connectedClients)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}
