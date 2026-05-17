import SwiftUI

struct ContentView: View {
    @ObservedObject var engine: StopwatchEngine

    var body: some View {
        VStack(spacing: 8) {
            Text(format(engine.elapsed))
                .font(.system(size: 56, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.yellow)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

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
            }
            .font(.system(size: 12))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minWidth: 200, minHeight: 90)
    }

    private func format(_ t: TimeInterval) -> String {
        let total = max(0, t)
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        let tenths = Int((total - floor(total)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}
