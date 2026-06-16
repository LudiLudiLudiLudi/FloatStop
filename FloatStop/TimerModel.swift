import Foundation
import Combine
import SwiftUI
import AppKit

/// Per-timer digit color presets. Affects only the main elapsed text.
enum TimerColor: String, CaseIterable, Codable {
    case yellow, blue, green, orange, purple, white

    var swiftUIColor: Color {
        switch self {
        case .yellow: return .yellow
        case .blue:   return .blue
        case .green:  return .green
        case .orange: return .orange
        case .purple: return .purple
        case .white:  return .white
        }
    }

    var displayName: String { rawValue.capitalized }
}

final class TimerModel: ObservableObject, Identifiable {
    let id: UUID
    @Published var title: String

    /// Read-only from outside; mutated only via `setTarget(_:)` so the three
    /// window fields (`targetDuration`, `targetStartedAt`, `targetEndDate`)
    /// always move together.
    @Published private(set) var targetDuration: TimeInterval?
    @Published private(set) var targetStartedAt: Date?
    @Published private(set) var targetEndDate: Date? {
        // Any change to the armed task-window end (arm / re-arm / clear) starts
        // a fresh alarm opportunity and (re)schedules the one-shot alarm.
        didSet { rescheduleTargetAlarm() }
    }

    @Published var elapsed: TimeInterval = 0
    @Published var isRunning: Bool = false

    /// Per-window appearance — independent of task content. Survives Reset.
    @Published var titleColor: TimerColor = .yellow
    @Published var digitColor: TimerColor = .yellow
    @Published var opacity: Double = 1.0
    @Published var titleFontSize: Double = 18
    @Published var digitFontSize: Double = 56

    /// Per-timer alarm sound (a macOS system-sound name, see `SystemSounds`).
    /// Used by the default `onTargetReached`. Like the rest of the model it is
    /// not persisted across launches.
    @Published var alarmSoundName: String = SystemSounds.defaultName

    private var startDate: Date?
    private var accumulated: TimeInterval = 0
    private var timer: Timer?

    /// When true, the display-refresh timer is suspended (e.g. the window is
    /// occluded or hidden). The stopwatch keeps running — `elapsed` is
    /// recomputed from wall-clock `Date()` whenever it next refreshes — so no
    /// time is lost; we simply stop redrawing what nobody can see.
    private var displayPaused = false

    // MARK: Target-reached alarm
    //
    // A single one-shot Timer scheduled for `targetEndDate`. It is NOT driven
    // by the per-second display refresh, so the alarm fires exactly once at the
    // target — never repeatedly on each redraw. `targetAlarmFired` is the
    // single-fire ("alreadyPlayed") guard; it resets whenever the target window
    // is re-armed, so a new task window can ring again.
    private var alarmTimer: Timer?
    private var targetAlarmFired = false

    /// Token for the system-wake observer. A one-shot `Timer` does not fire
    /// while the machine is asleep; if the target elapsed during sleep we ring
    /// once on wake instead (see `handleSystemWake`).
    private var wakeObserver: NSObjectProtocol?

    /// Invoked once when the task-window target is reached. Default rings the
    /// alarm (at least twice, using this timer's `alarmSoundName`) + Dock
    /// attention; overridable for tests. Assigned in `init` so it can read the
    /// per-timer sound at fire time.
    var onTargetReached: () -> Void = { TargetAlarm.shared.fire() }

    init(id: UUID = UUID(), title: String = "", targetDuration: TimeInterval? = nil) {
        self.id = id
        self.title = title
        if let d = targetDuration {
            setTarget(d)
        }
        // Default ring uses THIS timer's selected sound, resolved at fire time.
        onTargetReached = { [weak self] in
            TargetAlarm.shared.fire(soundName: self?.alarmSoundName)
        }
        // [weak self] so the notification center's retained block never keeps
        // this model alive (no Timer/closure → self retain cycle); removed in
        // prepareForRemoval / deinit. queue: nil → delivered synchronously.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleSystemWake()
        }
    }

    /// Canonical mutation path for the allocated task window.
    /// - nil duration → clears target, start, end.
    /// - duration set, window already started → preserves the original
    ///   `targetStartedAt`, recomputes `targetEndDate` as start + new duration
    ///   (so editing target mid-session extends/shrinks the existing window).
    /// - duration set, window not started → `targetEndDate` remains nil; the
    ///   next Start arms the window.
    func setTarget(_ duration: TimeInterval?) {
        guard let duration = duration else {
            targetDuration = nil
            targetStartedAt = nil
            targetEndDate = nil
            return
        }
        targetDuration = duration
        if let start = targetStartedAt {
            targetEndDate = start.addingTimeInterval(duration)
        } else {
            targetEndDate = nil
        }
    }

    func startPause() {
        if isRunning {
            pause()
        } else {
            resume()
        }
    }

    /// Reset clears task content only. Per-window appearance (color, opacity,
    /// titleFontSize, digitFontSize) is preserved — it's window style, not
    /// task state.
    func reset() {
        timer?.invalidate()
        timer = nil
        startDate = nil
        accumulated = 0
        elapsed = 0
        isRunning = false
        title = ""
        targetDuration = nil
        targetStartedAt = nil
        targetEndDate = nil
    }

    private func resume() {
        startDate = Date()
        isRunning = true
        // First Start after a target was set arms the wall-clock task window.
        // Subsequent Resumes do NOT touch `targetStartedAt` / `targetEndDate`,
        // because the window is tied to the original allocation, not to the
        // active-work stopwatch.
        if let duration = targetDuration, targetStartedAt == nil {
            let now = Date()
            targetStartedAt = now
            targetEndDate = now.addingTimeInterval(duration)
        }
        startDisplayTimer()
    }

    /// Start (or restart) the 1 Hz display-refresh timer, unless the display is
    /// currently paused (window occluded/hidden). 1 Hz matches the on-screen
    /// precision (MM:SS) and is 10× cheaper than the old 0.1 s tick; the
    /// tolerance lets the OS coalesce the fire for App Nap / energy efficiency.
    /// Accuracy is unaffected — `tick()` reads the wall clock each fire.
    private func startDisplayTimer() {
        timer?.invalidate()
        guard isRunning, !displayPaused else { return }
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        t.tolerance = 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Suspend or resume display refresh without affecting elapsed time.
    /// Called by the window controller when the panel becomes occluded/hidden
    /// or visible again. While paused, no redraw work happens at all.
    func setDisplayPaused(_ paused: Bool) {
        guard paused != displayPaused else { return }
        displayPaused = paused
        if paused {
            timer?.invalidate()
            timer = nil
        } else {
            // Becoming visible again: refresh the shown value once, then resume.
            tick()
            startDisplayTimer()
        }
    }

    /// (Re)schedule the one-shot target alarm from the current `targetEndDate`.
    /// Cancels any pending alarm and clears the single-fire guard first (the
    /// window changed), then arms a Timer only if the target is in the future.
    /// A target already in the past (e.g. restored/edited to a past value) does
    /// NOT auto-fire — that avoids a surprise ring on relaunch/edit.
    private func rescheduleTargetAlarm() {
        alarmTimer?.invalidate()
        alarmTimer = nil
        targetAlarmFired = false

        guard let end = targetEndDate else { return }
        let interval = end.timeIntervalSinceNow
        guard interval > 0 else { return }

        let t = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            self?.fireTargetAlarm()
        }
        t.tolerance = 0.5
        RunLoop.main.add(t, forMode: .common)
        alarmTimer = t
    }

    /// Fire exactly once per armed target window (guarded by `targetAlarmFired`).
    private func fireTargetAlarm() {
        guard !targetAlarmFired else { return }
        targetAlarmFired = true
        alarmTimer = nil
        onTargetReached()
    }

    /// On system wake, the one-shot alarm `Timer` may not have fired while the
    /// machine was asleep. If the armed target has already elapsed and we have
    /// not rung yet, ring exactly once now. The `targetAlarmFired` guard means a
    /// late catch-up fire from the original `Timer` cannot double-ring, so the
    /// alarm is delivered once — never retroactively several times — and no
    /// window needs to be reopened. A still-future target is left to its Timer.
    private func handleSystemWake() {
        guard let end = targetEndDate, !targetAlarmFired else { return }
        if end.timeIntervalSinceNow <= 0 {
            fireTargetAlarm()
        }
    }

    private func pause() {
        if let start = startDate {
            accumulated += Date().timeIntervalSince(start)
        }
        startDate = nil
        timer?.invalidate()
        timer = nil
        isRunning = false
        elapsed = accumulated
    }

    /// Permanently stop this timer because it's being closed/removed. Unlike
    /// the display pause (which keeps the stopwatch conceptually running so the
    /// time stays correct), this terminates the loop for good. Invalidating
    /// here makes the stop immediate rather than relying on deinit timing.
    func prepareForRemoval() {
        timer?.invalidate()
        timer = nil
        alarmTimer?.invalidate()
        alarmTimer = nil
        if let obs = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            wakeObserver = nil
        }
        startDate = nil
        isRunning = false
    }

    private func tick() {
        guard let start = startDate else { return }
        // The display timer is scheduled on RunLoop.main, so this fires on the
        // main thread. assumeIsolated turns that into a checked assertion for
        // the @MainActor DebugMetrics counters (opt-in; off by default).
        MainActor.assumeIsolated { DebugMetrics.recordTick() }
        elapsed = accumulated + Date().timeIntervalSince(start)
    }

    deinit {
        timer?.invalidate()
        alarmTimer?.invalidate()
        if let obs = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }
}
