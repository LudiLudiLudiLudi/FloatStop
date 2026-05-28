import Foundation
import Combine

final class TimerModel: ObservableObject, Identifiable {
    let id: UUID
    @Published var title: String
    @Published var targetDuration: TimeInterval?
    @Published var elapsed: TimeInterval = 0
    @Published var isRunning: Bool = false

    private var startDate: Date?
    private var accumulated: TimeInterval = 0
    private var timer: Timer?

    init(id: UUID = UUID(), title: String = "", targetDuration: TimeInterval? = nil) {
        self.id = id
        self.title = title
        self.targetDuration = targetDuration
    }

    func startPause() {
        if isRunning {
            pause()
        } else {
            resume()
        }
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        startDate = nil
        accumulated = 0
        elapsed = 0
        isRunning = false
        title = ""
        targetDuration = nil
    }

    private func resume() {
        startDate = Date()
        isRunning = true
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func pause() {
        if let start = startDate {
            accumulated += Date().timeIntervalSince(start)
        }
        startDate = nil
        timer?.invalidate()
        timer = nil
        isRunning = false
        elapsed = accumulated
    }

    private func tick() {
        guard let start = startDate else { return }
        elapsed = accumulated + Date().timeIntervalSince(start)
    }
}
