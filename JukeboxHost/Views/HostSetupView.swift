import JukeboxCore
import SwiftUI

struct HostSetupView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "music.note.house.fill")
                .font(.system(size: 72))
                .foregroundStyle(.pink.gradient)

            VStack(spacing: 8) {
                Text("Jukebox Host")
                    .font(.largeTitle.bold())
                Text("常設iPhoneをホストとして起動し、\n参加者は同じWi-Fiからアクセスします")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label(
                    model.musicAuthorized ? "Apple Music 利用可能" : "Apple Music の許可が必要です",
                    systemImage: model.musicAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(model.musicAuthorized ? .green : .orange)

                if let ip = JukeboxServer.localIPAddress() {
                    Label("Wi-Fi: \(ip)", systemImage: "wifi")
                } else {
                    Label("Wi-Fi に接続してください", systemImage: "wifi.slash")
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            Button {
                Task { await model.startHostServer() }
            } label: {
                Text("ホストを開始")
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

            Spacer()
        }
        .padding(24)
    }
}
