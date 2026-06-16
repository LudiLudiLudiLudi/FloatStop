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
    /// The most recent preview sound, so a new preview can stop it.
    private var previewSound: NSSound?

    /// Performs ONE ring of the named sound and reports whether it actually
    /// started playing. Overridable for tests. Default plays an independent
    /// system-sound instance.
    lazy var ringAction: (String?) -> Bool = { [weak self] name in
        self?.playSystemRing(named: name) ?? false
    }

    /// A fresh closure performing the DEFAULT real ring, independent of any
    /// current `ringAction` override. Lets tests wrap-and-count the real
    /// NSSound path without depending on prior test mutations.
    var defaultRingAction: (String?) -> Bool {
        { [weak self] name in self?.playSystemRing(named: name) ?? false }
    }

    /// Ring until at least `max(2, times)` rings have SUCCESSFULLY played (not
    /// merely been scheduled), each spaced by a short gap so they're distinct.
    /// `soundName` selects which system sound to ring (nil → default chain).
    /// `requestUserAttention` is the no-permission visual fallback that works
    /// while unfocused. A refused `play()` is retried, but the total attempt
    /// count is bounded by `maxExtraAttempts`, so audio failure degrades to the
    /// visual cue instead of an infinite loop.
    func fire(times: Int = 2, soundName: String? = nil) {
        NSApp.requestUserAttention(.criticalRequest)
        let needed = max(2, times)
        scheduleRing(soundName: soundName, successesNeeded: needed,
                     attemptsLeft: needed + maxExtraAttempts, delay: 0)
    }

    /// Play the named system sound once, immediately, for an in-UI preview.
    /// Stops any in-flight preview first so rapid clicks don't pile up.
    func preview(_ name: String) {
        previewSound?.stop()
        guard let base = NSSound(named: NSSound.Name(name)) else { return }
        let instance = (base.copy() as? NSSound) ?? base
        previewSound = instance
        instance.play()
    }

    /// Sequentially attempt rings, decrementing `successesNeeded` only on a
    /// successful `play()` and `attemptsLeft` on every attempt. Stops when
    /// enough rings have sounded or the attempt budget is exhausted.
    private func scheduleRing(soundName: String?, successesNeeded: Int,
                              attemptsLeft: Int, delay: TimeInterval) {
        guard successesNeeded > 0 else { return }   // enough audible rings — done
        guard attemptsLeft > 0 else {               // bounded — never spin
            NSLog("[FloatStop] alarm: could not play the required rings; relied on the visual attention fallback")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            let played = self.ringAction(soundName)
            self.scheduleRing(
                soundName: soundName,
                successesNeeded: played ? successesNeeded - 1 : successesNeeded,
                attemptsLeft: attemptsLeft - 1,
                delay: self.gapBetweenRings
            )
        }
    }

    /// Play one independent instance of the named system sound. Falls back
    /// through Glass → Submarine → Ping if the requested name is missing, so an
    /// unknown/stale selection still rings. Returns whether playback started.
    /// `NSSound(named:)` returns a SHARED cached instance, so a second `play()`
    /// while the first is still sounding is refused — we copy it per ring so
    /// each ring is its own instance and plays reliably.
    private func playSystemRing(named name: String?) -> Bool {
        let candidates = [name, "Glass", "Submarine", "Ping"].compactMap { $0 }
        guard let base = candidates.lazy
            .compactMap({ NSSound(named: NSSound.Name($0)) })
            .first else { return false }
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
