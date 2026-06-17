import JukeboxCore
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct HostSetupView: View {
    @EnvironmentObject private var model: AppModel

    private var hostDeviceLabel: String {
        #if os(macOS)
        "Mac"
        #else
        "iPhone / iPad"
        #endif
    }

    private var outputNote: String {
        #if os(macOS)
        "Mac のスピーカー / ヘッドホン出力に対応"
        #else
        "3.5mm ジャック / Lightning・USB-C 変換アダプタ経由の有線出力に対応"
        #endif
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.house.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.pink.gradient)
                        Text("Jukebox Host")
                            .font(.title.bold())
                        Text("常設 \(hostDeviceLabel) をホストとして起動し、参加者は同じ Wi-Fi からアクセスします")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                if let url = model.participantURL {
                    Section("参加用 QR") {
                        ParticipantQRCodeCard(
                            url: url,
                            localURL: model.participantLocalURL,
                            qrSize: 200
                        )
                        Button {
                            Task { await model.refreshJoinAddress() }
                        } label: {
                            Label("Wi-Fi 変更後に QR を更新", systemImage: "arrow.clockwise")
                        }
                        Text("参加者 URL は起動中に勝手には切り替えません。Wi-Fi を変えた時だけ手動更新してください。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let localURL = model.participantLocalURL {
                    Section("参加用 QR") {
                        ParticipantQRCodeCard(url: localURL, qrSize: 200)
                            .listRowInsets(EdgeInsets())
                        Text("サーバー起動時の IP で QR を固定します")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let ip = JukeboxServer.localIPAddress() {
                    Section("ネットワーク") {
                        LabeledContent("IP アドレス", value: ip)
                        Text("サーバーを起動すると QR コードが表示されます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("状態") {
                    LabeledContent("Apple Music", value: model.musicAuthorized ? "利用可能" : "許可が必要")
                    LabeledContent("音声出力", value: model.audioOutput.routeDetail)
                    #if os(iOS)
                    LabeledContent("外部ディスプレイ", value: model.externalDisplay.isExternalConnected ? "接続中" : "未接続")
                    #endif
                }

                Section("出力") {
                    Text(outputNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    #if os(iOS)
                    Text("HDMI には映像のみ表示し、音声は下の出力先から別途選択できます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("HDMI にパーティー画面を表示", isOn: Binding(
                        get: { model.externalDisplay.preferExternalDisplay },
                        set: {
                            model.externalDisplay.preferExternalDisplay = $0
                            model.externalDisplay.refreshConnections()
                        }
                    ))
                    Toggle("接続時はこの端末を操作パネルに", isOn: Binding(
                        get: { model.externalDisplay.deviceShowsControlsOnly },
                        set: { model.externalDisplay.deviceShowsControlsOnly = $0 }
                    ))
                    HStack {
                        Text("音声出力")
                        Spacer()
                        AudioRoutePickerView(tint: .secondaryLabel)
                            .frame(width: 32, height: 32)
                    }
                    #elseif os(macOS)
                    Button("サウンド設定を開く") {
                        MacAudioDevice.openSoundSettings()
                    }
                    #endif
                    Text("YouTube / Spotify は参加者ごとにログイン。Apple Music はホスト共有です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("画面・電源") {
                    Label("画面消灯防止（サーバー稼働中）", systemImage: "sun.max.fill")
                        .foregroundStyle(.green)
                    Text("常設運用時は画面が自動で消えないようにしています。バッテリー残量に注意してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        Task { await model.startHostServer() }
                    } label: {
                        Text(model.isServerRunning ? "サーバーを再起動" : "サーバーを起動")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)

                    if model.isServerRunning {
                        NavigationLink {
                            HostDurabilitySheet()
                        } label: {
                            Label("耐久・メトリクス", systemImage: "waveform.path.ecg")
                        }
                    }

                    if let error = model.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("セットアップ")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        .onAppear { model.audioOutput.refreshMacOutput() }
        #endif
    }
}
