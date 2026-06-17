import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import IOKit.pwr_mgt
#endif

enum PlatformOpenURL {
    @MainActor
    static func open(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}

#if os(macOS)
@MainActor
final class MacSleepInhibitor {
    private var assertionID: IOPMAssertionID = 0

    func start() {
        guard assertionID == 0 else { return }
        let reason = "Jukebox Host is running" as CFString
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
    }

    func stop() {
        guard assertionID != 0 else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }
}
#endif
