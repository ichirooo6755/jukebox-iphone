import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct HostPersistentQRPanel: View {
    let joinURL: String
    let localURL: String?
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .trailing, spacing: 6) {
                Label("参加 QR", systemImage: "qrcode")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))

                QRCodeImage(content: joinURL, size: 92)

                Text(joinURL)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .frame(maxWidth: 148, alignment: .trailing)

                if let localURL, localURL != joinURL {
                    Text("LAN: \(localURL)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                        .frame(maxWidth: 148, alignment: .trailing)
                }
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("参加者用 QR コード")
        .accessibilityHint("タップで拡大表示")
    }
}

struct DisplayContainerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showParticipantQR = false
    @State private var showDurability = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                #if os(iOS)
                if model.externalDisplay.isExternalConnected && model.externalDisplay.deviceShowsControlsOnly {
                    HostDeviceControlView()
                } else {
                    switch model.displayMode {
                    case .nowPlayingQueue:
                        NowPlayingQueueView()
                    case .visualizer:
                        VisualizerView()
                    }
                }
                #else
                switch model.displayMode {
                case .nowPlayingQueue:
                    NowPlayingQueueView()
                case .visualizer:
                    VisualizerView()
                }
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(model.crossfadeOpacity)
            .animation(.easeInOut(duration: 0.4), value: model.displayMode)

            displayModeButton
                .padding(16)

            if let joinURL = model.participantURL {
                HostPersistentQRPanel(
                    joinURL: joinURL,
                    localURL: model.participantLocalURL
                ) {
                    showParticipantQR = true
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showParticipantQR) {
            if let url = model.participantURL {
                ParticipantQRCodeSheet(url: url)
            }
        }
        .sheet(isPresented: $showDurability) {
            HostDurabilitySheet()
        }
    }

    private var displayModeButton: some View {
        Menu {
            if let url = model.participantURL {
                Button {
                    showParticipantQR = true
                } label: {
                    Label("参加者 QR を表示", systemImage: "qrcode")
                }
                Button {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url, forType: .string)
                    #else
                    UIPasteboard.general.string = url
                    #endif
                } label: {
                    Label("参加者 URL をコピー", systemImage: "link")
                }
                Text(url)
            }
            Divider()
            ForEach(model.serviceAuthStatuses, id: \.service) { status in
                Label(
                    "\(status.service.displayName): \(status.isAuthenticated ? "ログイン済み" : "未ログイン")",
                    systemImage: status.isAuthenticated ? "checkmark.circle" : "exclamationmark.circle"
                )
            }
            Divider()
            Button {
                showDurability = true
            } label: {
                Label("耐久・メトリクス", systemImage: "waveform.path.ecg")
            }
            Divider()
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
