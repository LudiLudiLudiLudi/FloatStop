import Foundation

/// Opt-in, lightweight instrumentation for the main timer-display loop.
///
/// OFF by default — when disabled, `recordTick()` is a single bool check and
/// produces no output and effectively no cost. Enable it either way (both
/// default to disabled, and the value is resolved once at first use):
///
///   • defaults write com.eladperegrubens.FloatStop FloatStopDebugLoopLogging -bool YES
///   • launch with the FLOATSTOP_DEBUG_LOOP environment variable set (any value)
///
/// When enabled, it prints the number of loop iterations observed in each
/// rolling ~60-second window, e.g.:
///
///   [FloatStop][loop] 60 iterations in last 60.0s
///
/// The count aggregates every running timer's tick (so with N running timers
/// at 1 Hz you'd expect ≈ 60 × N), which is exactly the total redraw load you
/// want to watch.
///
/// Thread contract: this type is `@MainActor`-isolated, so the mutable
/// counters are compiler-guaranteed to be touched only on the main thread —
/// no `nonisolated(unsafe)`, no data race. The single caller
/// (`TimerModel.tick()`) reaches it via `MainActor.assumeIsolated`, which is a
/// *checked* assertion that we're on the main thread (the timer fires on
/// `RunLoop.main`), trapping rather than racing if that ever stops being true.
@MainActor
enum DebugMetrics {
    /// Resolved once. Stays false unless a flag explicitly opts in.
    static let isLoopLoggingEnabled: Bool = {
        if ProcessInfo.processInfo.environment["FLOATSTOP_DEBUG_LOOP"] != nil { return true }
        return UserDefaults.standard.bool(forKey: "FloatStopDebugLoopLogging")
    }()

    private static var windowStart: Date?
    private static var count = 0

    /// Call once per main-update-loop iteration. No-op (cheap bool check) when
    /// logging is disabled.
    static func recordTick() {
        guard isLoopLoggingEnabled else { return }
        let now = Date()
        guard let start = windowStart else {
            windowStart = now
            count = 1
            return
        }
        count += 1
        let elapsed = now.timeIntervalSince(start)
        if elapsed >= 60 {
            print(String(format: "[FloatStop][loop] %d iterations in last %.1fs", count, elapsed))
            windowStart = now
            count = 0
        }
    }
}
