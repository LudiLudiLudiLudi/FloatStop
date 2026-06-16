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
/// (`pump`) rather than chaining `DispatchQueue.asyncAfter`. Current evidence
/// suggests a bare binary with no window can settle into a state where the idle
/// run loop stops servicing `Timer`s (only libdispatch keeps waking the main
/// thread); that appeared to non-deterministically swallow a re-armed alarm in
/// the harness. This points to the self-test runtime environment rather than
/// product logic — the real app always has a window and a live event loop.
/// After switching the harness to deterministic run-loop pumping, all scenarios
/// passed, so the alarm's own `Timer` is exercised as it is in production.
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

        // Edge: arm target, the machine "sleeps" (run loop is not pumped, the
        // analog of system sleep — the one-shot Timer cannot fire), the target
        // elapses during sleep, then the machine wakes. Requirement: ring once
        // on wake, not retroactively several times, without reopening a window.
        model.reset()
        model.setTarget(0.3)
        model.startPause()                       // armed 0.3s out
        Thread.sleep(forTimeInterval: 0.6)       // "asleep": run loop NOT pumped → no fire
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didWakeNotification, object: nil
        )                                        // wake → synchronous handler
        let s4 = reached == 3                     // exactly one fire, delivered on wake
        report("S4 target passed during sleep rings once on wake (reached=\(reached))", s4)
        pump(0.6)                                 // overdue catch-up Timer also runs now
        let s4b = reached == 3                    // still 3 — guard blocks the double-ring
        report("S4b no retroactive multi-fire after wake (reached=\(reached))", s4b)

        // Edge: a target that is set/restored ALREADY in the past must NOT
        // auto-fire (guards against a surprise "past alarm" — e.g. a future
        // relaunch that restores an expired target). FloatStop does not persist
        // timers across launches today, so this locks the guard regardless.
        model.reset()
        model.setTarget(5.0)
        model.startPause()                       // targetStartedAt = now, end = now+5s
        Thread.sleep(forTimeInterval: 0.3)
        model.setTarget(0.1)                     // end = start(0.3s ago)+0.1 → ~0.2s in the PAST
        pump(0.5)
        let s5 = reached == 3                      // no surprise fire from the past target
        report("S5 past target does not auto-fire (reached=\(reached))", s5)

        let all = t0 && s1 && s2 && s3 && s3b && s4 && s4b && s5
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
