import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = TimerStore()
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyDockIconPreference()

        let controller = store.createDefaultTimer()
        controller.showWindow()

        self.menuBarController = MenuBarController(store: store)

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
