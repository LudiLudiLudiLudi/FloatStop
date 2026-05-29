import SwiftUI

struct ContentView: View {
    @ObservedObject var engine: TimerModel
    var onDuplicate: (() -> Void)?

    @State private var showingTargetEditor = false

    var body: some View {
        VStack(spacing: 6) {
            TextField("Timer", text: $engine.title)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)

            Text(formatElapsed(engine.elapsed))
                .font(.system(size: 56, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.yellow)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            // Allocated task window status. Always rendered for stable layout
            // (single space + opacity 0 when there's no target). Wall-clock
            // driven at 1 Hz via TimelineView, so "Window left" continues to
            // tick even while the active-work stopwatch is paused.
            //
            // This is a calculated display from `targetEndDate - now`, not an
            // autonomous countdown. Pausing the timer does not affect it.
            TimelineView(.periodic(from: Date(), by: 1.0)) { context in
                Text(targetLineText(at: context.date))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .opacity(engine.targetDuration != nil ? 1 : 0)
            }

            HStack(spacing: 12) {
                Button(engine.isRunning ? "Pause" : "Start") {
                    engine.startPause()
                }
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)

                Button("Reset") {
                    engine.reset()
                }
                .controlSize(.small)

                Menu {
                    Button("Set Target…") { showingTargetEditor = true }
                        .disabled(engine.isRunning)
                    if onDuplicate != nil {
                        Button("Duplicate Timer") { onDuplicate?() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .popover(isPresented: $showingTargetEditor, arrowEdge: .top) {
                    TargetEditorView(
                        currentTarget: engine.targetDuration,
                        onApply: { engine.setTarget($0) }
                    )
                }
            }
            .font(.system(size: 12))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minWidth: 220, minHeight: 130)
    }

    // MARK: - secondary line

    private func targetLineText(at now: Date) -> String {
        guard let duration = engine.targetDuration else { return " " }
        guard let endDate = engine.targetEndDate else {
            return "Target \(formatMMSS(duration)) · ready"
        }
        let delta = endDate.timeIntervalSince(now)
        if delta >= 0 {
            return "Window left \(formatMMSS(delta))"
        } else {
            return "+\(formatMMSS(-delta)) overtime"
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
