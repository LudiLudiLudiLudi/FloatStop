import AppKit

/// Opt-in runtime self-test for the target-reached alarm. OFF by default —
/// runs only when launched with the `FLOATSTOP_SELFTEST_ALARM` environment
/// variable. It exercises the required scenarios with short durations, prints
/// PASS/FAIL per check, and exits the process with code 0 (all pass) or 1.
///
/// FloatStop has no XCTest target, so this is the runnable test deliverable:
///   FLOATSTOP_SELFTEST_ALARM=1 /path/to/FloatStop
///
/// Timing note: the test drives time by explicitly *pumping* the run loop
/// (`pump`) rather than chaining `DispatchQueue.asyncAfter`. A bare binary with
/// no window settles into a state where the idle run loop stops servicing
/// `Timer`s (only libdispatch keeps waking the main thread), which would
/// non-deterministically swallow a re-armed alarm in the harness even though
/// the real app — which always has a window and live event loop — fires it.
/// Pumping keeps the run loop in a timer-servicing mode for the whole test, so
/// the alarm's own `Timer` is delivered exactly as it is in production.
enum AlarmSelfTest {
    /// Returns false if the self-test was not requested (normal launch). When it
    /// IS requested the test runs synchronously and terminates the process, so
    /// this never returns true — the caller's early-return guard is for clarity.
    @discardableResult
    static func runIfRequested() -> Bool {
        guard ProcessInfo.processInfo.environment["FLOATSTOP_SELFTEST_ALARM"] != nil else {
            return false
        }
        print("[AlarmSelfTest] start")

        // T0 — TargetAlarm rings at least twice for one fire().
        var rings = 0
        TargetAlarm.shared.ringAction = { rings += 1 }
        TargetAlarm.shared.fire(times: 2)

        // TimerModel reached-event semantics (separate from the audible ring).
        var reached = 0
        let model = TimerModel(title: "selftest", targetDuration: 0.5)
        model.onTargetReached = { reached += 1; print("[AlarmSelfTest] reached (#\(reached))") }
        model.startPause()        // arms the target 0.5 s out

        // Req 2 + 7a: reaching target rings (>=2) and fires the event once.
        pump(1.2)
        let t0 = rings >= 2
        let s1 = reached == 1
        report("T0 plays >= 2 (rings=\(rings))", t0)
        report("S1 reaching target fires once (reached=\(reached))", s1)

        // Req 4 + 7b: staying past the target does NOT replay (single-fire guard).
        pump(1.3)
        let s2 = reached == 1
        report("S2 no repeat past target (reached=\(reached))", s2)

        // Req 3 + 7c: re-arming a fresh window (the native analog of a "refresh"/
        // new run) clears the guard and fires exactly once more — no leftover or
        // duplicate from the previous window.
        model.reset()
        model.setTarget(0.5)
        model.startPause()
        pump(1.2)
        let s3 = reached == 2
        report("S3 re-arm fires once more (reached=\(reached))", s3)

        // Stays at exactly 2 — no duplicate trailing fire after the re-arm.
        pump(0.8)
        let s3b = reached == 2
        report("S3b stable, no duplicates (reached=\(reached))", s3b)

        let all = t0 && s1 && s2 && s3 && s3b
        print("[AlarmSelfTest] RESULT: \(all ? "ALL PASS" : "FAILURES PRESENT")")
        exit(all ? 0 : 1)
    }

    /// Synchronously advance ~`seconds` of real time while keeping the run loop
    /// pumping in a `Timer`-servicing mode, so the alarm's one-shot `Timer` and
    /// the ring's dispatch blocks are delivered deterministically.
    private static func pump(_ seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: deadline)
        }
    }

    private static func report(_ name: String, _ ok: Bool) {
        print("[AlarmSelfTest] \(ok ? "PASS" : "FAIL") — \(name)")
    }
}
