import AppKit

/// Plays the "target reached" alarm — at least twice, audibly — and nudges the
/// Dock as a no-permission visual fallback.
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
    /// Extra play attempts allowed beyond the required count if a `play()` is
    /// refused, so we still reach the minimum audible rings WITHOUT spinning
    /// forever. `needed + maxExtraAttempts` is the hard attempt ceiling.
    private let maxExtraAttempts = 4
    /// Held so the async NSSounds aren't deallocated mid-play.
    private var liveSounds: [NSSound] = []

    /// Performs ONE ring and reports whether it actually started playing.
    /// Overridable for tests. Default plays an independent system-sound instance.
    lazy var ringAction: () -> Bool = { [weak self] in self?.playSystemRing() ?? false }

    /// Ring until at least `max(2, times)` rings have SUCCESSFULLY played (not
    /// merely been scheduled), each spaced by a short gap so they're distinct.
    /// `requestUserAttention` is the no-permission visual fallback that works
    /// while unfocused. A refused `play()` is retried, but the total attempt
    /// count is bounded by `maxExtraAttempts`, so audio failure degrades to the
    /// visual cue instead of an infinite loop.
    func fire(times: Int = 2) {
        NSApp.requestUserAttention(.criticalRequest)
        let needed = max(2, times)
        scheduleRing(successesNeeded: needed, attemptsLeft: needed + maxExtraAttempts, delay: 0)
    }

    /// Sequentially attempt rings, decrementing `successesNeeded` only on a
    /// successful `play()` and `attemptsLeft` on every attempt. Stops when
    /// enough rings have sounded or the attempt budget is exhausted.
    private func scheduleRing(successesNeeded: Int, attemptsLeft: Int, delay: TimeInterval) {
        guard successesNeeded > 0 else { return }   // enough audible rings — done
        guard attemptsLeft > 0 else {               // bounded — never spin
            NSLog("[FloatStop] alarm: could not play the required rings; relied on the visual attention fallback")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            let played = self.ringAction()
            self.scheduleRing(
                successesNeeded: played ? successesNeeded - 1 : successesNeeded,
                attemptsLeft: attemptsLeft - 1,
                delay: self.gapBetweenRings
            )
        }
    }

    /// Play one independent system-sound instance. Returns whether playback
    /// actually started. `NSSound(named:)` returns a SHARED cached instance, so
    /// a second `play()` while the first is still sounding is refused — we copy
    /// it per ring so each ring is its own instance and plays reliably.
    private func playSystemRing() -> Bool {
        guard let base = NSSound(named: NSSound.Name("Glass"))
            ?? NSSound(named: NSSound.Name("Submarine"))
            ?? NSSound(named: NSSound.Name("Ping")) else { return false }
        let instance = (base.copy() as? NSSound) ?? base
        liveSounds.append(instance)
        let ok = instance.play()
        // Release the retained sound a little after it should have finished.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.liveSounds.removeAll { $0 === instance }
        }
        return ok
    }
}
