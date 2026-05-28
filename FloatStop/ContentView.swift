import SwiftUI

struct ContentView: View {
    @ObservedObject var engine: TimerModel
    var onDuplicate: (() -> Void)?

    @State private var showingTargetEditor = false

    var body: some View {
        VStack(spacing: 6) {
            TextField("Timer", text: $engine.title)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            Text(formatElapsed(engine.elapsed))
                .font(.system(size: 56, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.yellow)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            if engine.targetDuration != nil {
                Text(targetLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
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
                    if onDuplicate != nil {
                        Button("Duplicate Timer") { onDuplicate?() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .popover(isPresented: $showingTargetEditor, arrowEdge: .top) {
                    TargetEditorView(targetDuration: $engine.targetDuration)
                }
            }
            .font(.system(size: 12))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minWidth: 220, minHeight: 130)
    }

    // MARK: - formatting

    private var targetLine: String {
        guard let target = engine.targetDuration else { return "" }
        let remaining = target - engine.elapsed
        if remaining >= 0 {
            return "Target \(formatMMSS(target)) · \(formatMMSS(remaining)) remaining"
        } else {
            return "+\(formatMMSS(-remaining)) overtime"
        }
    }

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
