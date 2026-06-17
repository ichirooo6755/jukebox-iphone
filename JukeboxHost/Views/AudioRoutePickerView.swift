import SwiftUI

#if os(iOS)
import AVKit

struct AudioRoutePickerView: UIViewRepresentable {
    var tint: UIColor = .white

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = tint
        picker.activeTintColor = tint
        picker.prioritizesVideoDevices = false
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tint
        uiView.activeTintColor = tint
    }
}
#elseif os(macOS)
import AppKit

struct AudioRoutePickerView: View {
    var body: some View {
        Button {
            MacAudioDevice.openSoundSettings()
        } label: {
            Image(systemName: "speaker.wave.2.circle")
        }
        .buttonStyle(.plain)
        .help("サウンド設定を開く")
    }
}
#else
struct AudioRoutePickerView: View {
    var body: some View {
        EmptyView()
    }
}
#endif
