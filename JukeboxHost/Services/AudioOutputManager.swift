import Combine
import Foundation

#if os(iOS)
import AVFoundation
#endif

@MainActor
final class AudioOutputManager: ObservableObject {
    @Published private(set) var routeLabel = "スピーカー"
    @Published private(set) var routeDetail = "内蔵スピーカー"
    @Published private(set) var isHeadphoneConnected = false

    #if os(iOS)
    private var routeObserver: NSObjectProtocol?

    init() {
        configureSession()
        updateRoute()
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateRoute() }
        }
    }

    deinit {
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
        }
    }

    func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func updateRoute() {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs

        if let output = outputs.first {
            switch output.portType {
            case .headphones, .headsetMic:
                isHeadphoneConnected = true
                routeLabel = "ヘッドフォン"
                routeDetail = "3.5mm / 有線出力"
            case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
                isHeadphoneConnected = false
                routeLabel = "Bluetooth"
                routeDetail = output.portName
            case .builtInSpeaker:
                isHeadphoneConnected = false
                routeLabel = "スピーカー"
                routeDetail = "内蔵スピーカー（有線イヤホンを接続してください）"
            default:
                isHeadphoneConnected = output.portType == .headphones
                routeLabel = output.portName
                routeDetail = output.portType.rawValue
            }
        }
    }
    #else
    init() {
        routeLabel = "Mac 出力"
        routeDetail = "システムの既定オーディオ出力"
        isHeadphoneConnected = false
    }

    func configureSession() {}
    #endif

    var statusLine: String {
        "出力: \(routeLabel)"
    }
}
