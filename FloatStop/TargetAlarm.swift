import AppKit

/// Plays the "target reached" alarm at least twice, and nudges the Dock as a
/// no-permission visual fallback.
///
/// Native-macOS notes (vs the browser limitations the request mentions):
/// - `NSSound` plays regardless of whether the app/window is focused or in the
///   background — there is no "autoplay needs a user gesture" restriction like
///   in browsers, and no permission prompt for system sounds.
/// - `requestUserAttention(.criticalRequest)` bounces the Dock icon / draws
///   attention even when the app is unfocused; it needs no permission either,
///   and is the visual fallback in case audio output is muted/unavailable.
///
/// Main-thread only — driven from `TimerModel`'s one-shot alarm timer on
/// `RunLoop.main`.
final class TargetAlarm {
    static let shared = TargetAlarm()

    private let gapBetweenRings: TimeInterval = 0.35
    /// Held so the async NSSounds aren't deallocated mid-play.
    private var liveSounds: [NSSound] = []

    /// Performs ONE ring. Overridable for tests (replace with a counter).
    /// Default plays a system sound.
    lazy var ringAction: () -> Void = { [weak self] in self?.playSystemRing() }

    /// Ring `times` times (clamped to a minimum of 2 per the spec), each ring
    /// spaced by a short gap so they're distinct. Also requests user attention
    /// as a visual fallback that works while unfocused.
    func fire(times: Int = 2) {
        NSApp.requestUserAttention(.criticalRequest)
        let count = max(2, times)
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * gapBetweenRings) { [weak self] in
                self?.ringAction()
            }
        }
    }

    private func playSystemRing() {
        guard let ring = NSSound(named: NSSound.Name("Glass"))
            ?? NSSound(named: NSSound.Name("Submarine"))
            ?? NSSound(named: NSSound.Name("Ping")) else { return }
        liveSounds.append(ring)
        ring.play()
        // Release the retained sound a little after it should have finished.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.liveSounds.removeAll { $0 === ring }
        }
    }
}
