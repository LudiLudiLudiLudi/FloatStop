import Foundation
import Combine
import SwiftUI

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
    @Published private(set) var targetEndDate: Date?

    @Published var elapsed: TimeInterval = 0
    @Published var isRunning: Bool = false

    /// Per-window appearance — independent of task content. Survives Reset.
    @Published var titleColor: TimerColor = .yellow
    @Published var digitColor: TimerColor = .yellow
    @Published var opacity: Double = 1.0
    @Published var titleFontSize: Double = 18
    @Published var digitFontSize: Double = 56

    private var startDate: Date?
    private var accumulated: TimeInterval = 0
    private var timer: Timer?

    /// When true, the display-refresh timer is suspended (e.g. the window is
    /// occluded or hidden). The stopwatch keeps running — `elapsed` is
    /// recomputed from wall-clock `Date()` whenever it next refreshes — so no
    /// time is lost; we simply stop redrawing what nobody can see.
    private var displayPaused = false

    init(id: UUID = UUID(), title: String = "", targetDuration: TimeInterval? = nil) {
        self.id = id
        self.title = title
        if let d = targetDuration {
            setTarget(d)
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

    private func tick() {
        guard let start = startDate else { return }
        elapsed = accumulated + Date().timeIntervalSince(start)
    }

    deinit {
        timer?.invalidate()
    }
}
