import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct HostNetworkBanner: View {
    let localURL: String?
    let joinURL: String?

    var body: some View {
        if let localURL {
            VStack(alignment: .leading, spacing: 4) {
                Label("この端末の IP", systemImage: "wifi")
                    .font(.caption.weight(.semibold))
                Text(localURL)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                if let joinURL, joinURL != localURL {
                    Text("QR: \(joinURL)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct DisplayContainerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showParticipantQR = false
    @State private var showDurability = false
    @State private var didPresentInitialQR = false

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

            participantQRButton
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HostNetworkBanner(
                localURL: model.participantLocalURL,
                joinURL: model.participantURL
            )
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
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
        .onAppear {
            guard !didPresentInitialQR, model.participantURL != nil else { return }
            didPresentInitialQR = true
            showParticipantQR = true
        }
    }

    private var participantQRButton: some View {
        Button {
            showParticipantQR = true
        } label: {
            Image(systemName: "qrcode")
                .font(.title3)
                .foregroundColor(.white)
                .padding(12)
                .background(.ultraThinMaterial, in: Circle())
        }
        .disabled(model.participantURL == nil)
        .opacity(model.participantURL == nil ? 0.35 : 1)
        .accessibilityLabel("参加者用 QR コードを表示")
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
