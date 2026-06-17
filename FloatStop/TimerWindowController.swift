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

        let hosting = FirstMouseHostingView(rootView: ContentView(
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

        // Surface the window when its alert turns on while it is hidden (the
        // user hid it BEFORE the target). The sound was already rung by the
        // model, so we only bring the window forward + start blinking. This is
        // a FIRST show, not a re-show: the user can dismiss it with any control.
        model.$isAlerting
            .sink { [weak self] alerting in
                guard let self, alerting, !self.panel.isVisible else { return }
                self.surfaceForAlert()
            }
            .store(in: &cancellables)
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

    /// Hide ALWAYS succeeds immediately, and it WINS over the alert: if the
    /// timer is alerting, Hide acknowledges it (synchronously, idempotently) so
    /// the window never resurfaces on its own — the user can always make it go
    /// away. The timer keeps running and the controller stays in the store, so
    /// "Show All Timers" can still bring it back manually.
    func hide() {
        model.acknowledgeAlert()   // dismiss the alert first → controls win
        panel.orderOut(nil)
    }

    /// Bring the window visually forward for an alert WITHOUT stealing keyboard
    /// focus (orderFrontRegardless, not makeKey) and resume its display refresh.
    /// Guarded by `isAlerting`: once the alert has been dismissed this is a
    /// no-op, so a dismissal can never be undone by a late surface.
    private func surfaceForAlert() {
        guard model.isAlerting else { return }
        model.setDisplayPaused(false)
        panel.orderFrontRegardless()
    }

    /// Close ALWAYS succeeds immediately. While the timer is alerting the
    /// control must win, so we skip the destructive-confirmation modal (a modal
    /// run loop opened from an inactive / non-key surfaced window can trap the
    /// app) and close at once, acknowledging the alert synchronously first.
    /// When NOT alerting, keep the normal confirmation.
    func confirmAndClose() {
        if model.isAlerting {
            model.acknowledgeAlert()
            onClose?()
            return
        }
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

    /// Manual restore (e.g. "Show All Timers").
    func showWindow() {
        panel.makeKeyAndOrderFront(nil as Any?)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

/// Hosting view that accepts the first mouse click even when its window is not
/// key. Guarantees the timer's in-window controls (Hide / ⊖ / Reset) respond on
/// the FIRST click after the window auto-surfaces for an alert — when the app
/// may be inactive and the panel non-key — so window controls always win.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
