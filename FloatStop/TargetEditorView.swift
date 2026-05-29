import SwiftUI

/// Small popover for setting (or clearing) a timer's target duration.
/// Minutes only — no seconds, no presets, no Pomodoro.
///
/// Uses a closure callback (not a Binding) so all target mutations route
/// through `TimerModel.setTarget(_:)`, which keeps `targetDuration`,
/// `targetStartedAt`, and `targetEndDate` consistent.
struct TargetEditorView: View {
    let currentTarget: TimeInterval?
    let onApply: (TimeInterval?) -> Void

    @State private var minutesText: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Target duration")
                .font(.headline)

            HStack(spacing: 6) {
                TextField("40", text: $minutesText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .onSubmit(applyAndDismiss)
                Text("minutes")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Clear") {
                    onApply(nil)
                    dismiss()
                }
                .disabled(currentTarget == nil)

                Spacer()

                Button("Cancel") { dismiss() }

                Button("Set", action: applyAndDismiss)
                    .keyboardShortcut(.defaultAction)
                    .disabled(parsedMinutes == nil)
            }
        }
        .padding(14)
        .frame(width: 240)
        .onAppear {
            if let t = currentTarget {
                minutesText = String(Int(t / 60))
            }
        }
    }

    private var parsedMinutes: Int? {
        guard let m = Int(minutesText), m > 0 else { return nil }
        return m
    }

    private func applyAndDismiss() {
        if let m = parsedMinutes {
            onApply(TimeInterval(m * 60))
        }
        dismiss()
    }
}
