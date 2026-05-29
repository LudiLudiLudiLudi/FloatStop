import SwiftUI

private enum ActivePopover: Identifiable {
    case target
    case appearance
    var id: Self { self }
}

struct ContentView: View {
    @ObservedObject var engine: TimerModel
    var onDuplicate: (() -> Void)?

    @State private var activePopover: ActivePopover?

    var body: some View {
        VStack(spacing: 6) {
            TextField("Timer", text: $engine.title)
                .textFieldStyle(.plain)
                .font(.system(size: CGFloat(engine.titleFontSize), weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(engine.titleColor.swiftUIColor)
                .frame(maxWidth: .infinity)

            Text(formatElapsed(engine.elapsed))
                .font(.system(size: CGFloat(engine.digitFontSize), weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(engine.digitColor.swiftUIColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

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

                Menu {
                    Button("Set Target…") { activePopover = .target }
                        .disabled(engine.isRunning)

                    Button("Appearance…") { activePopover = .appearance }

                    if onDuplicate != nil {
                        Button("Duplicate Timer") { onDuplicate?() }
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
                            onApply: { engine.setTarget($0) }
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
        let total = max(0, t)
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        let tenths = Int((total - floor(total)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }

    private func formatMMSS(_ t: TimeInterval) -> String {
        let total = max(0, t)
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
