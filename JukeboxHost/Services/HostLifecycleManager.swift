import Foundation
import Network
import UIKit

@MainActor
final class HostLifecycleManager {
    private var pathMonitor: NWPathMonitor?
    private var monitorQueue = DispatchQueue(label: "jukebox.network")
    private var onNetworkRestored: (() async -> Void)?
    private var onServerRestartNeeded: (() async -> Void)?
    private var wasConnected = true
    private var watchdogTask: Task<Void, Never>?
    private var foregroundObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?

    func start(
        onNetworkRestored: @escaping () async -> Void,
        onServerRestartNeeded: @escaping () async -> Void
    ) {
        self.onNetworkRestored = onNetworkRestored
        self.onServerRestartNeeded = onServerRestartNeeded

        UIApplication.shared.isIdleTimerDisabled = true

        pathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let connected = path.status == .satisfied
                if connected, !self.wasConnected {
                    await onNetworkRestored()
                }
                self.wasConnected = connected
            }
        }
        pathMonitor?.start(queue: monitorQueue)

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.onServerRestartNeeded?() }
        }

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            // バックグラウンドでも音声再生を継続（audio background mode）
        }

        startWatchdog()
    }

    func stop() {
        watchdogTask?.cancel()
        watchdogTask = nil
        pathMonitor?.cancel()
        pathMonitor = nil
        UIApplication.shared.isIdleTimerDisabled = false

        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
    }

    private func startWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await onServerRestartNeeded?()
            }
        }
    }
}
