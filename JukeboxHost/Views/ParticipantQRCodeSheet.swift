import CoreImage.CIFilterBuiltins
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum QRCodeGenerator {
    static func image(for string: String) -> Image? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }

        #if os(macOS)
        let size = NSSize(width: scaled.extent.width, height: scaled.extent.height)
        return Image(nsImage: NSImage(cgImage: cgImage, size: size))
        #else
        return Image(uiImage: UIImage(cgImage: cgImage))
        #endif
    }
}

struct QRCodeImage: View {
    let content: String
    let size: CGFloat

    var body: some View {
        if let qrImage = QRCodeGenerator.image(for: content) {
            qrImage
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .padding(12)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "qrcode")
                    .font(.largeTitle)
                Text("QRコードを生成できません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
        }
    }
}

struct ParticipantQRCodeCard: View {
    let url: String
    var localURL: String? = nil
    var qrSize: CGFloat = 160
    var showsCopyButton = true

    var body: some View {
        VStack(spacing: 12) {
            Label("参加者用 QR", systemImage: "qrcode")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Netlify 経由で LAN 内の Web UI へ案内します（同じ Wi-Fi が必要）")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let localURL, localURL != url {
                Text("LAN: \(localURL)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .center, spacing: 16) {
                QRCodeImage(content: url, size: qrSize)

                VStack(alignment: .leading, spacing: 8) {
                    Text(url)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if showsCopyButton {
                        Button("URL をコピー") {
                            copyURL()
                        }
                        .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func copyURL() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        #else
        UIPasteboard.general.string = url
        #endif
    }
}

struct ParticipantQRCodeSheet: View {
    let url: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Netlify 経由で LAN 内の Web UI へ案内します（同じ Wi-Fi が必要）")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                QRCodeImage(content: url, size: 240)

                Text(url)
                    .font(.system(.footnote, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)

                Button("URL をコピー") {
                    copyURL()
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("参加者用 QR")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 460)
        #endif
    }

    private func copyURL() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        #else
        UIPasteboard.general.string = url
        #endif
    }
}
