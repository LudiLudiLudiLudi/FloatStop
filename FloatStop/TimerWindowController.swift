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
    /// the controller). Invoked by both the in-window "Close Timer" menu item
    /// and the red window close button.
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
            onClose: { [weak self] in self?.onClose?() }
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

    /// Red window close button → real close (terminate this timer), not the
    /// old orderOut-only "hide". We do the teardown via onClose and return
    /// false so AppKit doesn't also run its default close path.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onClose?()
        return false
    }

    func showWindow() {
        panel.makeKeyAndOrderFront(nil as Any?)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
