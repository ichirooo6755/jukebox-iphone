#if os(iOS)
import SwiftUI
import UIKit

@MainActor
final class ExternalDisplayManager: ObservableObject {
    @Published private(set) var isExternalConnected = false
    @Published private(set) var externalScreenSize: String?
    @Published var preferExternalDisplay: Bool {
        didSet { UserDefaults.standard.set(preferExternalDisplay, forKey: "host_prefer_external_display") }
    }
    @Published var deviceShowsControlsOnly: Bool {
        didSet { UserDefaults.standard.set(deviceShowsControlsOnly, forKey: "host_device_controls_only") }
    }

    private weak var model: AppModel?
    private var externalWindow: UIWindow?
    private var observers: [NSObjectProtocol] = []

    init() {
        preferExternalDisplay = UserDefaults.standard.object(forKey: "host_prefer_external_display") as? Bool ?? true
        deviceShowsControlsOnly = UserDefaults.standard.object(forKey: "host_device_controls_only") as? Bool ?? true
    }

    func attach(model: AppModel) {
        self.model = model
        startObserving()
        refreshConnections()
    }

    func detach() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        teardownExternalWindow()
    }

    func refreshConnections() {
        guard let model else { return }
        let externalScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { scene in
                scene.session.role == .windowExternalDisplayNonInteractive
            }

        if preferExternalDisplay, let scene = externalScenes.first {
            setupWindow(on: scene, model: model)
            isExternalConnected = true
            let size = scene.screen.bounds.size
            externalScreenSize = "\(Int(size.width))×\(Int(size.height))"
        } else {
            teardownExternalWindow()
            isExternalConnected = false
            externalScreenSize = nil
        }
    }

    private func startObserving() {
        let names: [Notification.Name] = [
            UIScene.didActivateNotification,
            UIScene.willDeactivateNotification,
            UIScene.didDisconnectNotification,
        ]
        for name in names {
            let token = NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.refreshConnections() }
            }
            observers.append(token)
        }
    }

    private func setupWindow(on scene: UIWindowScene, model: AppModel) {
        if externalWindow?.windowScene == scene { return }
        teardownExternalWindow()

        let root = UIHostingController(
            rootView: ExternalDisplayView()
                .environmentObject(model)
        )
        root.view.backgroundColor = .black

        let window = UIWindow(windowScene: scene)
        window.rootViewController = root
        window.isHidden = false
        externalWindow = window
    }

    private func teardownExternalWindow() {
        externalWindow?.isHidden = true
        externalWindow?.rootViewController = nil
        externalWindow = nil
    }
}
#endif
