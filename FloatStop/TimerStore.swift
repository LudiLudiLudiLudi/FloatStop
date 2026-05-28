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

    // MARK: - private

    private func bindDuplicate(_ controller: TimerWindowController) {
        controller.onDuplicate = { [weak self, weak controller] in
            guard let self, let controller else { return }
            self.duplicate(controller)
        }
    }
}
