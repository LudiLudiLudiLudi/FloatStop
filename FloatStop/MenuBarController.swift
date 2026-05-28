import AppKit
import ServiceManagement

private let hideDockIconKey = "FloatStop.hideDockIcon"

final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let store: TimerStore

    private let newTimerItem = NSMenuItem(title: "New Timer", action: #selector(newTimer), keyEquivalent: "")
    private let showAllItem = NSMenuItem(title: "Show All Timers", action: #selector(showAll), keyEquivalent: "")
    private let hideAllItem = NSMenuItem(title: "Hide All Timers", action: #selector(hideAll), keyEquivalent: "")
    private let closeAllItem = NSMenuItem(title: "Close All Timers", action: #selector(closeAll), keyEquivalent: "")
    private let hideDockIconItem = NSMenuItem(title: "Hide Dock Icon", action: #selector(toggleHideDockIcon), keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    init(store: TimerStore) {
        self.store = store
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

        [newTimerItem, showAllItem, hideAllItem, closeAllItem, hideDockIconItem, launchAtLoginItem].forEach {
            $0.target = self
        }
        menu.addItem(newTimerItem)
        menu.addItem(showAllItem)
        menu.addItem(hideAllItem)
        menu.addItem(closeAllItem)
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
        hideDockIconItem.state = UserDefaults.standard.bool(forKey: hideDockIconKey) ? .on : .off
        launchAtLoginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
    }

    @objc private func newTimer() {
        store.newTimer()
    }

    @objc private func showAll() {
        store.showAll()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func hideAll() {
        store.hideAll()
    }

    @objc private func closeAll() {
        store.closeAll()
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
