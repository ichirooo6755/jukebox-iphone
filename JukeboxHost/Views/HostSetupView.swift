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
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 24)

                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.pink.gradient)

                VStack(spacing: 8) {
                    Text("Jukebox Host")
                        .font(.largeTitle.bold())
                    Text("常設 \(hostDeviceLabel) をホストとして起動し、\n参加者は同じ Wi-Fi からアクセスします")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let url = model.participantURL {
                    ParticipantQRCodeCard(
                        url: url,
                        localURL: model.participantLocalURL,
                        qrSize: 180
                    )
                } else if let localURL = model.participantLocalURL {
                    ParticipantQRCodeCard(url: localURL, qrSize: 180)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label(
                        model.musicAuthorized ? "Apple Music 利用可能" : "Apple Music の許可が必要です",
                        systemImage: model.musicAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(model.musicAuthorized ? .green : .orange)

                    Label(model.audioOutput.statusLine, systemImage: model.audioOutput.isHeadphoneConnected ? "headphones" : "speaker.wave.2")

                    if model.participantURL == nil {
                        if let ip = JukeboxServer.localIPAddress() {
                            Label("ネットワーク: \(ip)", systemImage: "wifi")
                        } else {
                            Label("ネットワークに接続してください", systemImage: "wifi.slash")
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(outputNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("YouTube は参加者ごとにログインします。Spotify はホスト共有です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                Button {
                    Task { await model.startHostServer() }
                } label: {
                    Text(model.isServerRunning ? "サーバーを再起動" : "サーバーを起動")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)

                if let error = model.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer(minLength: 24)
            }
            .padding(24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }
}
