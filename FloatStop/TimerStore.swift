import Foundation

/// Owns all timer windows. At this step it only manages a single default
/// timer; later steps add New / Duplicate / Close / Hide / Show All /
/// persistence on top of the same collection.
final class TimerStore: ObservableObject {
    @Published private(set) var controllers: [TimerWindowController] = []

    @discardableResult
    func createDefaultTimer() -> TimerWindowController {
        let controller = TimerWindowController()
        controllers.append(controller)
        return controller
    }

    func showAll() {
        for c in controllers { c.showWindow() }
    }

    func hideAll() {
        for c in controllers { c.panel.orderOut(nil) }
    }
}
