import SwiftUI

#if os(iOS)
import MediaPlayer

struct VolumeSliderView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = false
        view.tintColor = .white
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
#elseif os(macOS)
struct VolumeSliderView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(.white.opacity(0.7))
            Text("音量はメニューバーの音量キーまたはサウンド設定で調整")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Button("サウンド設定") {
                MacAudioDevice.openSoundSettings()
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
