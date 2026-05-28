import AppKit
import SwiftUI

/// Owns one timer's model, its floating panel, and its hosting view.
/// At this step there is still exactly one controller per app launch;
/// the seam exists so that later steps can hold many of these in a store.
final class TimerWindowController {
    let model: TimerModel
    let panel: FloatingPanel

    init(model: TimerModel = TimerModel(),
         contentRect: NSRect = NSRect(x: 0, y: 0, width: 280, height: 120),
         centered: Bool = true) {
        self.model = model

        let panel = FloatingPanel(
            contentRect: contentRect,
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        let hosting = NSHostingView(rootView: ContentView(engine: model))
        panel.contentView = hosting
        panel.isReleasedWhenClosed = false
        if centered { panel.center() }

        self.panel = panel
    }

    func showWindow() {
        panel.makeKeyAndOrderFront(nil as Any?)
    }
}
