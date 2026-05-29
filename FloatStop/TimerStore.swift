import AppKit

/// Owns all timer windows. At this step it supports the default launch
/// timer plus user-initiated New and Duplicate. Hide / Close / persistence
/// arrive in later steps.
final class TimerStore: ObservableObject {
    @Published private(set) var controllers: [TimerWindowController] = []

    @discardableResult
    func createDefaultTimer() -> TimerWindowController {
        let controller = TimerWindowController()
        bindDuplicate(controller)
        controllers.append(controller)
        return controller
    }

    /// New empty timer — shown immediately, paused at 00:00.
    @discardableResult
    func newTimer() -> TimerWindowController {
        let controller = createDefaultTimer()
        controller.showWindow()
        return controller
    }

    /// New paused timer with `title` and `targetDuration` copied from the
    /// source. Elapsed/running state are NOT copied.
    @discardableResult
    func duplicate(_ source: TimerWindowController) -> TimerWindowController {
        let copiedModel = TimerModel(
            title: source.model.title,
            targetDuration: source.model.targetDuration
        )
        // Duplicate carries the source's visual style; the task window itself
        // (targetStartedAt / targetEndDate) does NOT carry over — the duplicate
        // is in `ready` state, per Step 5.1.2 spec.
        copiedModel.titleColor = source.model.titleColor
        copiedModel.digitColor = source.model.digitColor
        copiedModel.opacity = source.model.opacity
        copiedModel.titleFontSize = source.model.titleFontSize
        copiedModel.digitFontSize = source.model.digitFontSize
        let srcFrame = source.panel.frame
        let offset: CGFloat = 30
        let newFrame = NSRect(
            x: srcFrame.origin.x + offset,
            y: srcFrame.origin.y - offset,
            width: srcFrame.size.width,
            height: srcFrame.size.height
        )
        let controller = TimerWindowController(
            model: copiedModel,
            contentRect: newFrame,
            centered: false
        )
        bindDuplicate(controller)
        controllers.append(controller)
        controller.showWindow()
        return controller
    }

    func showAll() {
        for c in controllers { c.showWindow() }
    }

    func hideAll() {
        for c in controllers { c.panel.orderOut(nil) }
    }

    /// Removes all timer windows. Running timers are stopped, panels are
    /// ordered out, and controllers drop their last strong reference.
    /// After this call `controllers` is empty; the user can create fresh
    /// timers via New Timer.
    func closeAll() {
        for c in controllers {
            c.panel.orderOut(nil)
            // TimerModel.deinit invalidates its Timer when the controller
            // is dropped from the array.
        }
        controllers.removeAll()
    }

    // MARK: - private

    private func bindDuplicate(_ controller: TimerWindowController) {
        controller.onDuplicate = { [weak self, weak controller] in
            guard let self, let controller else { return }
            self.duplicate(controller)
        }
    }
}
