import Foundation

public enum DurabilityLog {
    private static let key = "jukebox.durability.events"

    public static func record(_ event: String) {
        var events = load()
        events.append("\(ISO8601DateFormatter().string(from: Date())) \(event)")
        if events.count > 200 { events.removeFirst(events.count - 200) }
        UserDefaults.standard.set(events, forKey: key)
    }

    public static func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    public static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
