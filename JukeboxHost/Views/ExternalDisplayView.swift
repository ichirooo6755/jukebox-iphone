import JukeboxCore
import SwiftUI

#if os(iOS)
struct ExternalDisplayView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            NowPlayingQueueView()
                .environmentObject(model)
        }
        .preferredColorScheme(.dark)
    }
}

struct HostDeviceControlView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showQR = false

    var body: some View {
        NavigationStack {
            List {
                if let url = model.participantLocalURL {
                    Section("参加用 QR") {
                        ParticipantQRCodeCard(url: url, qrSize: 200)
                            .listRowInsets(EdgeInsets())
                            .frame(maxWidth: .infinity)
                    }
                }

                Section("再生") {
                    if let current = model.playbackState.current {
                        LabeledContent(current.title, value: current.artist)
                    } else {
                        Text("待機中").foregroundStyle(.secondary)
                    }
                    HStack {
                        Button {
                            Task { await model.togglePlayback() }
                        } label: {
                            Image(systemName: model.playbackState.isPlaying ? "pause.fill" : "play.fill")
                        }
                        Button {
                            Task { await model.skip() }
                        } label: {
                            Image(systemName: "forward.end.fill")
                        }
                    }
                    .font(.title2)
                }

                Section("音声出力（HDMI とは別）") {
                    Text("映像は HDMI / 外部ディスプレイ、音声はここで選んだ出力先に流れます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LabeledContent("現在", value: model.audioOutput.routeDetail)
                    HStack {
                        Text("出力先を変更")
                        Spacer()
                        AudioRoutePickerView(tint: .secondaryLabel)
                            .frame(width: 36, height: 36)
                    }
                }

                Section("外部ディスプレイ") {
                    LabeledContent("接続", value: model.externalDisplay.isExternalConnected ? "接続中" : "未接続")
                    if let size = model.externalDisplay.externalScreenSize {
                        LabeledContent("解像度", value: size)
                    }
                    Toggle("HDMI にパーティー画面を表示", isOn: Binding(
                        get: { model.externalDisplay.preferExternalDisplay },
                        set: {
                            model.externalDisplay.preferExternalDisplay = $0
                            model.externalDisplay.refreshConnections()
                        }
                    ))
                    Toggle("この端末は操作パネルのみ", isOn: Binding(
                        get: { model.externalDisplay.deviceShowsControlsOnly },
                        set: { model.externalDisplay.deviceShowsControlsOnly = $0 }
                    ))
                }

                Section("画面") {
                    Label("画面消灯防止 ON", systemImage: "sun.max.fill")
                        .foregroundStyle(.green)
                    Text("サーバー稼働中は自動で画面が消えないようにしています。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("ホスト操作")
        }
    }
}
#endif
