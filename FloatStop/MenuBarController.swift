import AppKit
import ServiceManagement

private let hideDockIconKey = "FloatStop.hideDockIcon"

final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let panel: NSPanel
    private let engine: TimerModel

    private let showHideItem = NSMenuItem(title: "Hide FloatStop", action: #selector(toggleShowHide), keyEquivalent: "")
    private let startPauseItem = NSMenuItem(title: "Start", action: #selector(startPause), keyEquivalent: "")
    private let resetItem = NSMenuItem(title: "Reset", action: #selector(reset), keyEquivalent: "")
    private let hideDockIconItem = NSMenuItem(title: "Hide Dock Icon", action: #selector(toggleHideDockIcon), keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    init(panel: NSPanel, engine: TimerModel) {
        self.panel = panel
        self.engine = engine
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.menu = NSMenu()
        super.init()

        if let button = statusItem.button {
            button.toolTip = "FloatStop"
            button.title = ""
            let symbol = NSImage(systemSymbolName: "stopwatch", accessibilityDescription: "FloatStop")
                ?? NSImage(systemSymbolName: "timer", accessibilityDescription: "FloatStop")
            if let img = symbol {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "⏱"
            }
        }

        menu.delegate = self

        [showHideItem, startPauseItem, resetItem, hideDockIconItem, launchAtLoginItem].forEach {
            $0.target = self
        }
        menu.addItem(showHideItem)
        menu.addItem(.separator())
        menu.addItem(startPauseItem)
        menu.addItem(resetItem)
        menu.addItem(.separator())
        menu.addItem(hideDockIconItem)
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit FloatStop", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        updateMenuItems()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuItems()
    }

    private func updateMenuItems() {
        showHideItem.title = panel.isVisible ? "Hide FloatStop" : "Show FloatStop"
        startPauseItem.title = engine.isRunning ? "Pause" : "Start"
        hideDockIconItem.state = UserDefaults.standard.bool(forKey: hideDockIconKey) ? .on : .off
        launchAtLoginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
    }

    @objc private func toggleShowHide() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        updateMenuItems()
    }

    @objc private func startPause() {
        engine.startPause()
        updateMenuItems()
    }

    @objc private func reset() {
        engine.reset()
        updateMenuItems()
    }

    @objc private func toggleHideDockIcon() {
        let defaults = UserDefaults.standard
        let newValue = !defaults.bool(forKey: hideDockIconKey)
        defaults.set(newValue, forKey: hideDockIconKey)
        NSApp.setActivationPolicy(newValue ? .accessory : .regular)
        if !newValue {
            NSApp.activate(ignoringOtherApps: true)
        }
        updateMenuItems()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            print("FloatStop: failed to update Launch at Login: \(error)")
        }
        updateMenuItems()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
