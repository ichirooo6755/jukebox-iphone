import Foundation

/// Loads API credentials into the process environment before JukeboxCore services initialize.
enum SecretsLoader {
    private static let keys = [
        "SPOTIFY_CLIENT_ID",
        "SPOTIFY_CLIENT_SECRET",
        "YOUTUBE_API_KEY",
        "YOUTUBE_CLIENT_ID",
        "YOUTUBE_CLIENT_SECRET",
        "OAUTH_PUBLIC_REDIRECT_URI",
    ]

    static func load() {
        loadFromPlist(named: "Secrets", in: .main)
        loadFromDotEnv()
    }

    private static func loadFromPlist(named name: String, in bundle: Bundle) {
        guard let url = bundle.url(forResource: name, withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(
                  from: data,
                  format: nil
              ) as? [String: String]
        else { return }

        for (key, value) in dict where !value.isEmpty {
            setenv(key, value, 0)
        }
    }

    private static func loadFromDotEnv() {
        let candidates = [
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent(".env"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(".env")
        ]

        for url in candidates {
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }
            parseDotEnv(contents)
            return
        }
    }

    private static func parseDotEnv(_ contents: String) {
        for line in contents.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            var value = parts[1].trimmingCharacters(in: .whitespaces)
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
                (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            guard keys.contains(key), !value.isEmpty else { continue }
            setenv(key, value, 0)
        }
    }
}
