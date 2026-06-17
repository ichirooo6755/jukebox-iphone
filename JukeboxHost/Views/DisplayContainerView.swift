import SwiftUI

struct DisplayContainerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch model.displayMode {
                case .nowPlayingQueue:
                    NowPlayingQueueView()
                case .visualizer:
                    VisualizerView()
                }
            }
            .opacity(model.crossfadeOpacity)
            .animation(.easeInOut(duration: 0.4), value: model.displayMode)

            displayModeButton
                .padding(16)
        }
        .ignoresSafeArea(edges: hSize == .regular ? .all : [])
    }

    private var displayModeButton: some View {
        Menu {
            ForEach(HostDisplayMode.allCases) { mode in
                Button {
                    withAnimation { model.displayMode = mode }
                } label: {
                    Label(mode.title, systemImage: mode.icon)
                }
            }
        } label: {
            Image(systemName: model.displayMode.icon)
                .font(.title3)
                .foregroundColor(.white)
                .padding(12)
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}
