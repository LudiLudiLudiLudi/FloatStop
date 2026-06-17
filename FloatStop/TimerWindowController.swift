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

    /// Snooze re-show timer. Armed when an ALERTING timer is hidden: the hide
    /// is honored immediately but does not acknowledge, and after `snoozeInterval`
    /// the still-unacknowledged alert resurfaces (and replays the sound).
    private var snoozeTimer: Timer?
    /// Default 60 s; overridable via FLOATSTOP_SNOOZE_SECONDS for quick testing.
    private let snoozeInterval: TimeInterval = {
        if let s = ProcessInfo.processInfo.environment["FLOATSTOP_SNOOZE_SECONDS"],
           let v = Double(s), v > 0 {
            return v
        }
        return 60
    }()

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

        // Surface the window when its alert turns on while it is hidden (the
        // user hid it BEFORE the target). The sound was already rung by the
        // model, so we only bring the window forward + start blinking. When the
        // alert is acknowledged, cancel any pending snooze re-show.
        model.$isAlerting
            .sink { [weak self] alerting in
                guard let self else { return }
                if alerting {
                    if !self.panel.isVisible {
                        self.surfaceForAlert(replaySound: false)
                    }
                } else {
                    self.cancelSnooze()
                }
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

    /// Non-destructive hide: order the window out. The timer keeps running and
    /// the controller stays in the store, so "Show All Timers" brings it back.
    /// Hiding an ACTIVELY ALERTING timer does NOT acknowledge the alert — it
    /// snoozes: the window leaves now (blinking stops because nothing renders),
    /// and after `snoozeInterval` the still-unacknowledged alert resurfaces.
    func hide() {
        panel.orderOut(nil)
        if model.isAlerting {
            startSnooze()
        }
    }

    /// Bring the window visually forward for an alert WITHOUT stealing keyboard
    /// focus (orderFrontRegardless, not makeKey) and resume its display refresh.
    /// The panel sits at `.floating` level, so it lands above normal windows.
    private func surfaceForAlert(replaySound: Bool) {
        model.setDisplayPaused(false)
        panel.orderFrontRegardless()
        if replaySound {
            TargetAlarm.shared.fire(soundName: model.alarmSoundName)
        }
    }

    private func startSnooze() {
        cancelSnooze()
        let t = Timer(timeInterval: snoozeInterval, repeats: false) { [weak self] _ in
            self?.snoozeFired()
        }
        t.tolerance = 1.0
        RunLoop.main.add(t, forMode: .common)
        snoozeTimer = t
    }

    private func snoozeFired() {
        snoozeTimer = nil
        // If the user acknowledged during the snooze, stay dismissed.
        guard model.isAlerting else { return }
        surfaceForAlert(replaySound: true)
    }

    private func cancelSnooze() {
        snoozeTimer?.invalidate()
        snoozeTimer = nil
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

    /// Manual restore (e.g. "Show All Timers"). Cancels any pending snooze so an
    /// alert the user has already brought back doesn't fire a duplicate re-show.
    func showWindow() {
        cancelSnooze()
        panel.makeKeyAndOrderFront(nil as Any?)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        snoozeTimer?.invalidate()
    }
}
