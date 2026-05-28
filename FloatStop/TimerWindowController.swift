import AppKit
import SwiftUI

/// Owns one timer's model, its floating panel, and its hosting view.
/// `onDuplicate` is set by `TimerStore` so the per-window UI can ask the
/// store to clone this controller.
final class TimerWindowController {
    let model: TimerModel
    let panel: FloatingPanel
    var onDuplicate: (() -> Void)?

    init(model: TimerModel = TimerModel(),
         contentRect: NSRect = NSRect(x: 0, y: 0, width: 280, height: 160),
         centered: Bool = true) {
        self.model = model
        self.panel = FloatingPanel(
            contentRect: contentRect,
            styleMask: [],
            backing: .buffered,
            defer: false
        )

        let hosting = NSHostingView(rootView: ContentView(
            engine: model,
            onDuplicate: { [weak self] in self?.onDuplicate?() }
        ))
        panel.contentView = hosting
        panel.isReleasedWhenClosed = false
        if centered { panel.center() }
    }

    func showWindow() {
        panel.makeKeyAndOrderFront(nil as Any?)
    }
}
