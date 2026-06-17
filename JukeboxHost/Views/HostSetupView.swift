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
                            qrSize: 180
                        )
                        .listRowInsets(EdgeInsets())
                    }
                } else if let localURL = model.participantLocalURL {
                    Section("参加用 QR") {
                        ParticipantQRCodeCard(url: localURL, qrSize: 180)
                            .listRowInsets(EdgeInsets())
                    }
                }

                Section("状態") {
                    LabeledContent("Apple Music", value: model.musicAuthorized ? "利用可能" : "許可が必要")
                    LabeledContent("音声出力", value: model.audioOutput.routeDetail)
                    if model.participantURL == nil {
                        if let ip = JukeboxServer.localIPAddress() {
                            LabeledContent("ネットワーク", value: ip)
                        } else {
                            LabeledContent("ネットワーク", value: "未接続")
                        }
                    }
                }

                Section("出力") {
                    Text(outputNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    #if os(iOS)
                    HStack {
                        Text("AirPlay / Bluetooth / 有線")
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
