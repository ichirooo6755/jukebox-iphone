import Foundation

public enum ArtworkURLNormalizer {
  public static func normalize(_ url: String?) -> String? {
    guard var value = url?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }

    value = value
      .replacingOccurrences(of: "{w}", with: "300")
      .replacingOccurrences(of: "{h}", with: "300")
      .replacingOccurrences(of: "%7Bw%7D", with: "300", options: .caseInsensitive)
      .replacingOccurrences(of: "%7Bh%7D", with: "300", options: .caseInsensitive)

    if value.hasPrefix("http://") {
      value = "https://" + value.dropFirst("http://".count)
    }

    return value
  }
}
