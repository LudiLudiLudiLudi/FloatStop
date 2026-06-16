import AppKit

/// The macOS system sounds available for the target-reached alarm. Discovered
/// at runtime from `/System/Library/Sounds`, with a fixed fallback list (the
/// stock Sonoma set) in case the directory can't be read. Names are the bare
/// basenames that `NSSound(named:)` accepts (e.g. "Glass").
enum SystemSounds {
    /// Default ring used by a fresh timer.
    static let defaultName = "Glass"

    /// The stock macOS system sounds, used as a fallback if directory discovery
    /// fails (and to define a sensible order if discovery succeeds).
    static let fallback = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]

    /// All selectable sounds, sorted alphabetically. Always contains at least
    /// `defaultName` so the picker is never empty.
    static let all: [String] = discover()

    private static func discover() -> [String] {
        let dir = "/System/Library/Sounds"
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        let found = entries
            .filter { $0.hasSuffix(".aiff") }
            .map { ($0 as NSString).deletingPathExtension }
            .filter { NSSound(named: NSSound.Name($0)) != nil }
        let names = found.isEmpty ? fallback : found
        var unique = Array(Set(names)).sorted()
        if !unique.contains(defaultName) { unique.insert(defaultName, at: 0) }
        return unique
    }

    /// Clamp an arbitrary stored value to a known sound; unknown → default.
    static func resolve(_ name: String?) -> String {
        guard let name, all.contains(name) else { return defaultName }
        return name
    }
}
