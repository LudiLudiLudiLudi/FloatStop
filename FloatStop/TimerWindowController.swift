import AppKit
import SwiftUI
import Combine

/// Owns one timer's model, its floating panel, and its hosting view.
/// `onDuplicate` is set by `TimerStore` so the per-window UI can ask the
/// store to clone this controller. The controller also mirrors the model's
/// `opacity` onto `panel.alphaValue` live, so the slider feels responsive.
final class TimerWindowController: NSObject, NSWindowDelegate {
    let model: TimerModel
    let panel: FloatingPanel
    var onDuplicate: (() -> Void)?
    /// Set by TimerStore. Permanently closes this timer (stops it + removes
    /// the controller). Invoked only after the user confirms in
    /// `confirmAndClose()` (reached from the red ✕ or the "Close Timer" menu).
    var onClose: (() -> Void)?

    private var cancellables: Set<AnyCancellable> = []

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
        super.init()

        let hosting = NSHostingView(rootView: ContentView(
            engine: model,
            onDuplicate: { [weak self] in self?.onDuplicate?() },
            onHide: { [weak self] in self?.hide() },
            onRequestClose: { [weak self] in self?.confirmAndClose() }
        ))
        panel.contentView = hosting
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        if centered { panel.center() }

        // Mirror model.opacity onto the panel's alphaValue. Initial value plus
        // a Combine subscription that lives for the controller's lifetime.
        panel.alphaValue = CGFloat(model.opacity)
        model.$opacity
            .sink { [weak panel] newValue in
                panel?.alphaValue = CGFloat(newValue)
            }
            .store(in: &cancellables)

        // Pause display refresh whenever the panel isn't actually visible
        // (occluded by other windows, or ordered out). A running timer that
        // nobody can see then costs ~zero CPU; elapsed stays exact and the
        // shown value is refreshed the moment the panel becomes visible again.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(occlusionChanged),
            name: NSWindow.didChangeOcclusionStateNotification,
            object: panel
        )
    }

    @objc private func occlusionChanged() {
        model.setDisplayPaused(!panel.occlusionState.contains(.visible))
    }

    /// Red window close button = DESTRUCTIVE close, with confirmation. We run
    /// the teardown ourselves (after the user confirms) and return false so
    /// AppKit never runs its own close path.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        confirmAndClose()
        return false
    }

    /// Non-destructive hide: just order the window out. The timer keeps
    /// running and the controller stays in the store, so "Show All Timers"
    /// brings it back.
    func hide() {
        panel.orderOut(nil)
    }

    /// Confirm, then permanently close this timer (stop it + remove it from
    /// the store via `onClose`). Cancel leaves it running and visible.
    func confirmAndClose() {
        let alert = NSAlert()
        alert.messageText = "Close Timer?"
        alert.informativeText = "This will stop and remove this timer."
        alert.alertStyle = .warning
        let closeButton = alert.addButton(withTitle: "Close Timer") // .alertFirstButtonReturn
        alert.addButton(withTitle: "Cancel")
        if #available(macOS 11.0, *) { closeButton.hasDestructiveAction = true }
        if alert.runModal() == .alertFirstButtonReturn {
            onClose?()
        }
    }

    func showWindow() {
        panel.makeKeyAndOrderFront(nil as Any?)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
