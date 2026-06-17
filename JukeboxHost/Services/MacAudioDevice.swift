#if os(macOS)
import AppKit
import CoreAudio
import Foundation

enum MacAudioDevice {
    static func defaultOutputName() -> String {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        ) == noErr else {
            return "システム既定"
        }

        var name: CFString = "" as CFString
        size = UInt32(MemoryLayout<CFString>.size)
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &size, &name) == noErr else {
            return "システム既定"
        }
        return name as String
    }

    static func openSoundSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound") else { return }
        NSWorkspace.shared.open(url)
    }
}
#endif
