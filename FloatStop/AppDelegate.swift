import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = TimerStore()
    private var menuBarController: MenuBarController?

    /// Patch marker for THIS performance build. Bump when the perf behaviour
    /// changes so a launched binary can be identified unambiguously in logs.
    private static let perfBuildMarker = "perf-1hz+occlusion-pause"

    func applicationDidFinishLaunching(_ notification: Notification) {
        logBuildMarker()
        applyDockIconPreference()

        let controller = store.createDefaultTimer()
        controller.showWindow()

        self.menuBarController = MenuBarController(store: store)

        NSApp.activate(ignoringOtherApps: true)
    }

    /// One-time launch line so you can confirm the FIXED binary is running.
    /// Always printed (not gated by the debug-logging flag) — it's a single
    /// line at launch, not a loop. Includes the bundle version/build and the
    /// perf patch marker.
    private func logBuildMarker() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        print("[FloatStop] launch — v\(version) (build \(build)) [\(Self.perfBuildMarker)]")
        fflush(stdout)   // flush now so the marker is visible even when stdout
                         // is a pipe/file (block-buffered) and the process is
                         // later killed without a graceful stdio flush.
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func applyDockIconPreference() {
        let hideDockIcon = UserDefaults.standard.bool(forKey: "FloatStop.hideDockIcon")
        NSApp.setActivationPolicy(hideDockIcon ? .accessory : .regular)
    }
}
