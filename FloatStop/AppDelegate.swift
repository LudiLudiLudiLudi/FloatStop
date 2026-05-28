import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var timerWindow: TimerWindowController?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyDockIconPreference()

        let controller = TimerWindowController()
        controller.showWindow()

        self.timerWindow = controller
        self.menuBarController = MenuBarController(panel: controller.panel, engine: controller.model)

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
