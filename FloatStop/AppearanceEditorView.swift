import SwiftUI

/// Per-window appearance popover: title color, digit color, title size,
/// digit size, opacity. All five bind directly to the model so changes
/// apply live while the popover is open.
struct AppearanceEditorView: View {
    @ObservedObject var engine: TimerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            ColorSwatchRow(label: "Title color", selected: $engine.titleColor)
            ColorSwatchRow(label: "Timer color", selected: $engine.digitColor)

            Divider()

            HStack {
                Text("Title size")
                Spacer()
                Text("\(Int(engine.titleFontSize))")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 24, alignment: .trailing)
                Stepper("", value: $engine.titleFontSize, in: 12...36, step: 2)
                    .labelsHidden()
            }

            HStack {
                Text("Timer size")
                Spacer()
                Text("\(Int(engine.digitFontSize))")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 24, alignment: .trailing)
                Stepper("", value: $engine.digitFontSize, in: 28...96, step: 4)
                    .labelsHidden()
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Opacity")
                    Spacer()
                    Text("\(Int(engine.opacity * 100))%")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, alignment: .trailing)
                }
                Slider(value: $engine.opacity, in: 0.35...1.0)
            }
        }
        .padding(14)
        .frame(width: 260)
    }
}

/// One labelled row of six color swatches. Selected swatch carries a
/// primary-color ring; the others sit with a faint stroke.
private struct ColorSwatchRow: View {
    let label: String
    @Binding var selected: TimerColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.headline)
            HStack(spacing: 8) {
                ForEach(TimerColor.allCases, id: \.self) { c in
                    Button {
                        selected = c
                    } label: {
                        Circle()
                            .fill(c.swiftUIColor)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(
                                        selected == c ? Color.primary : Color.secondary.opacity(0.4),
                                        lineWidth: selected == c ? 2 : 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .help(c.displayName)
                }
            }
        }
    }
}
