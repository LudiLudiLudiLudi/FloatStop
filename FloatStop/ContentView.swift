import SwiftUI

private enum ActivePopover: Identifiable {
    case target
    case appearance
    var id: Self { self }
}

struct ContentView: View {
    @ObservedObject var engine: TimerModel
    var onDuplicate: (() -> Void)?
    /// Hide THIS timer's window (non-destructive). Timer keeps running; the
    /// window comes back via "Show All Timers".
    var onHide: (() -> Void)?
    /// Request a destructive close of THIS timer. Shows a confirmation first
    /// (same path as the red ✕). On confirm it stops and removes the timer.
    var onRequestClose: (() -> Void)?

    @State private var activePopover: ActivePopover?

    var body: some View {
        VStack(spacing: 6) {
            TextField("Timer", text: $engine.title)
                .textFieldStyle(.plain)
                .font(.system(size: CGFloat(engine.titleFontSize), weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(engine.titleColor.swiftUIColor)
                .frame(maxWidth: .infinity)

            // Timer digits. When the target alarm is active (`isAlerting`), the
            // digits blink — a smooth ~2 Hz fade driven by a sine on the
            // animation clock. Blinking is OPACITY ONLY, so the layout never
            // resizes or shifts. The TimelineView(.animation) high-frequency
            // refresh runs ONLY while alerting; the rest of the time the digits
            // are static (preserving the 1 Hz idle-CPU behavior). The blink
            // continues until the alert is acknowledged — it is not tied to the
            // one-shot sound.
            Group {
                if engine.isAlerting {
                    TimelineView(.animation) { context in
                        digitsText.opacity(blinkOpacity(at: context.date))
                    }
                } else {
                    digitsText
                }
            }

            // Allocated task window status. The TimelineView's 1 Hz refresh is
            // only paid for when a target exists. With no target, render a
            // static reserved line of the same height so the rest of the
            // layout doesn't move.
            //
            // While active, the line reads from `targetEndDate - now` (wall-
            // clock driven). It keeps ticking even while the active-work
            // stopwatch is paused, because Pause does not stop the task window.
            // This is a calculated display, not an autonomous countdown.
            if engine.targetDuration != nil {
                TimelineView(.periodic(from: Date(), by: 1.0)) { context in
                    Text(targetLineText(at: context.date))
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
            } else {
                Text(" ")
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 12) {
                Button {
                    engine.startPause()
                } label: {
                    Text(engine.isRunning ? "Pause" : "Start")
                }
                .buttonStyle(.borderedProminent)
                .tint(engine.isRunning ? .orange : .blue)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)

                Button("Reset") {
                    engine.reset()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.regular)

                // Dedicated Hide: non-destructive, distinct from Close. The
                // window leaves the screen but the timer keeps running and its
                // state is preserved; "Show All Timers" brings it back.
                if onHide != nil {
                    Button {
                        onHide?()
                    } label: {
                        Image(systemName: "eye.slash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Hide only — the timer keeps running; restore it with Show All Timers")
                }

                Menu {
                    Button("Set Target…") { activePopover = .target }
                        .disabled(engine.isRunning)

                    Button("Appearance…") { activePopover = .appearance }

                    if onDuplicate != nil {
                        Button("Duplicate Timer") { onDuplicate?() }
                    }

                    if onHide != nil || onRequestClose != nil {
                        Divider()
                    }
                    if onHide != nil {
                        Button("Hide Timer") { onHide?() }   // reversible: Show All brings it back
                            .help("Hide only — the timer keeps running")
                    }
                    if onRequestClose != nil {
                        Button("Close Timer", role: .destructive) { onRequestClose?() }  // confirms, then removes
                            .help("Close — stop and remove this timer")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .popover(item: $activePopover, arrowEdge: .bottom) { which in
                    switch which {
                    case .target:
                        TargetEditorView(
                            currentTarget: engine.targetDuration,
                            onApply: { engine.setTarget($0) },
                            alarmSoundName: $engine.alarmSoundName
                        )
                    case .appearance:
                        AppearanceEditorView(engine: engine)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minWidth: 220, minHeight: 130)
    }

    // MARK: - digits

    private var digitsText: some View {
        Text(formatElapsed(engine.elapsed))
            .font(.system(size: CGFloat(engine.digitFontSize), weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(engine.digitColor.swiftUIColor)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
    }

    /// Smooth blink opacity: a 2 Hz sine (two full fade cycles per second)
    /// ranging from a dim 0.15 to fully opaque 1.0.
    private func blinkOpacity(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        let phase = (sin(t * 2 * Double.pi * 2) + 1) / 2   // 0...1, 2 cycles/sec
        return 0.15 + 0.85 * phase
    }

    // MARK: - secondary line

    private func targetLineText(at now: Date) -> String {
        guard let duration = engine.targetDuration else { return " " }
        let windowLabel = "Task window \(formatMMSS(duration))"
        guard let endDate = engine.targetEndDate else {
            return "\(windowLabel) · ready"
        }
        let delta = endDate.timeIntervalSince(now)
        if delta >= 0 {
            return "\(windowLabel) · \(formatMMSS(delta)) left"
        } else {
            return "\(windowLabel) · +\(formatMMSS(-delta)) overtime"
        }
    }

    // MARK: - formatting

    private func formatElapsed(_ t: TimeInterval) -> String {
        // Whole seconds only. The display refreshes at 1 Hz (see TimerModel),
        // so showing tenths here would just stutter at 10× the CPU cost. The
        // underlying elapsed value stays exact — only the shown precision
        // changed.
        let total = max(0, t)
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatMMSS(_ t: TimeInterval) -> String {
        let total = max(0, t)
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
