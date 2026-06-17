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

        // R0 — exercise the REAL ring chain end to end: TargetAlarm.fire →
        // NSSound.play(). We wrap (not replace) the default ring so the real
        // system sound is played AND we can count how many plays SUCCEEDED.
        // Asserts two rings actually return play() == true — the earlier bug was
        // that the 2nd play() on a shared NSSound was refused (only 1 audible).
        var realPlays = 0
        let realRing = TargetAlarm.shared.ringAction
        TargetAlarm.shared.ringAction = { name in
            let ok = realRing(name)
            if ok { realPlays += 1 }
            return ok
        }
        TargetAlarm.shared.fire(times: 2)
        pump(2.0)
        let r0 = realPlays >= 2
        report("R0 two real rings played (play()==true) (realPlays=\(realPlays))", r0)

        // T0 — TargetAlarm invokes the ring action at least twice for one
        // fire() (audio-independent: a pure counter that always "succeeds").
        var rings = 0
        TargetAlarm.shared.ringAction = { _ in rings += 1; return true }
        TargetAlarm.shared.fire(times: 2)
        pump(1.5)
        let t0Done = rings >= 2
        report("T0 ring invoked >= 2 (rings=\(rings))", t0Done)

        // R3 — fire(soundName:) routes the SELECTED sound to every ring and the
        // real sound plays (>=2 successful). Wrap the default real ring to
        // record the requested names while still hitting NSSound for "Funk".
        var r3Names: [String?] = []
        var r3Plays = 0
        let r3Default = TargetAlarm.shared.defaultRingAction
        TargetAlarm.shared.ringAction = { name in
            r3Names.append(name)
            let ok = r3Default(name)
            if ok { r3Plays += 1 }
            return ok
        }
        TargetAlarm.shared.fire(times: 2, soundName: "Funk")
        pump(2.0)
        let r3 = r3Plays >= 2 && !r3Names.isEmpty && r3Names.allSatisfy { $0 == "Funk" }
        report("R3 selected sound routed + played (names=\(r3Names.compactMap { $0 }), plays=\(r3Plays))", r3)

        // R4 — an unknown/stale sound name still rings via the fallback chain.
        var r4Plays = 0
        let r4Default = TargetAlarm.shared.defaultRingAction
        TargetAlarm.shared.ringAction = { name in
            let ok = r4Default(name)
            if ok { r4Plays += 1 }
            return ok
        }
        TargetAlarm.shared.fire(times: 2, soundName: "NoSuchSound_zzz")
        pump(2.0)
        let r4 = r4Plays >= 2
        report("R4 unknown sound falls back and still rings (plays=\(r4Plays))", r4)

        // TimerModel reached-event semantics (separate from the audible ring).
        var reached = 0
        let model = TimerModel(title: "selftest", targetDuration: 0.5)
        model.onTargetReached = { reached += 1; print("[AlarmSelfTest] reached (#\(reached))") }
        model.startPause()        // arms the target 0.5 s out

        // Req 7a: reaching the target fires the reached event exactly once.
        pump(1.2)
        let s1 = reached == 1
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

        // ===== Persistent alert state machine (isAlerting) =====
        // B1: reaching the target raises the persistent alert flag.
        let m = TimerModel(title: "alert", targetDuration: 0.4)
        m.onTargetReached = {}                      // silence the sound for the test
        m.startPause()
        pump(0.9)
        let b1 = m.isAlerting == true
        report("B1 target reached raises isAlerting (\(m.isAlerting))", b1)

        // B2: the alert persists well after the (one-shot) sound would have ended.
        pump(1.5)
        let b2 = m.isAlerting == true
        report("B2 alert persists after sound ends (\(m.isAlerting))", b2)

        // B3: Reset acknowledges.
        m.reset()
        let b3 = m.isAlerting == false
        report("B3 Reset clears alert (\(m.isAlerting))", b3)

        // B4: Pause keeps the alert; Start (a new run) acknowledges.
        m.setTarget(0.4); m.startPause(); pump(0.9)
        let b4pre = m.isAlerting                    // alerting, running (overtime)
        m.startPause()                              // → Pause (NOT an acknowledgment)
        let b4paused = m.isAlerting
        m.startPause()                              // → Start a new run (acknowledges)
        let b4 = b4pre && b4paused && m.isAlerting == false
        report("B4 Pause keeps / Start clears (pre=\(b4pre) paused=\(b4paused) afterStart=\(m.isAlerting))", b4)

        // B5: Set new target acknowledges.
        m.reset(); m.setTarget(0.4); m.startPause(); pump(0.9)
        let b5pre = m.isAlerting
        m.setTarget(60)
        let b5 = b5pre && m.isAlerting == false
        report("B5 Set new target clears alert (pre=\(b5pre) after=\(m.isAlerting))", b5)

        // B6: Close (prepareForRemoval) acknowledges.
        m.reset(); m.setTarget(0.4); m.startPause(); pump(0.9)
        let b6pre = m.isAlerting
        m.prepareForRemoval()
        let b6 = b6pre && m.isAlerting == false
        report("B6 Close clears alert (pre=\(b6pre) after=\(m.isAlerting))", b6)

        // B7: two timers alert independently (per-window state).
        let mA = TimerModel(title: "A", targetDuration: 0.4); mA.onTargetReached = {}
        let mB = TimerModel(title: "B", targetDuration: 60);  mB.onTargetReached = {}
        mA.startPause(); mB.startPause(); pump(0.9)
        let b7 = mA.isAlerting == true && mB.isAlerting == false
        report("B7 two timers alert independently (A=\(mA.isAlerting) B=\(mB.isAlerting))", b7)

        let all = r0 && t0Done && r3 && r4 && s1 && s2 && s3 && s3b && s4 && s4b && s5
            && b1 && b2 && b3 && b4 && b5 && b6 && b7
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
