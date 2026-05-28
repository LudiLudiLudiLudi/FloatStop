import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = TimerModel()
    private var panel: FloatingPanel?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyDockIconPreference()

        let contentView = ContentView(engine: engine)
        let hosting = NSHostingView(rootView: contentView)

        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 120),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isReleasedWhenClosed = false
        panel.center()
        panel.makeKeyAndOrderFront(nil as Any?)

        self.panel = panel
        self.menuBarController = MenuBarController(panel: panel, engine: engine)

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func applyDockIconPreference() {
        let hideDockIcon = UserDefaults.standard.bool(forKey: "FloatStop.hideDockIcon")
        NSApp.setActivationPolicy(hideDockIcon ? .accessory : .regular)
    }
}
