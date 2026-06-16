import SwiftUI

/// Small popover for setting (or clearing) a timer's target duration and
/// choosing the alarm sound that rings when the target is reached.
/// Minutes only — no seconds, no presets, no Pomodoro.
///
/// The target uses a closure callback (not a Binding) so all target mutations
/// route through `TimerModel.setTarget(_:)`, which keeps `targetDuration`,
/// `targetStartedAt`, and `targetEndDate` consistent. The alarm sound is a
/// plain per-window setting, so it binds directly.
struct TargetEditorView: View {
    let currentTarget: TimeInterval?
    let onApply: (TimeInterval?) -> Void
    /// Per-window alarm sound (a `SystemSounds` name). Lives in the same
    /// behavioral scope as the target, not in a global preference.
    @Binding var alarmSoundName: String

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

            Divider()

            Text("Alarm sound")
                .font(.headline)
            HStack {
                // Custom binding so picking a sound previews it immediately.
                Picker("", selection: Binding(
                    get: { alarmSoundName },
                    set: { newValue in
                        alarmSoundName = newValue
                        TargetAlarm.shared.preview(newValue)
                    }
                )) {
                    ForEach(SystemSounds.all, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()

                Button {
                    TargetAlarm.shared.preview(alarmSoundName)
                } label: {
                    Image(systemName: "play.circle")
                }
                .buttonStyle(.borderless)
                .help("Preview sound")
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
