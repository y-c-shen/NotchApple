import Foundation

final class PomodoroController {
    private var endDate: Date?
    private var timer: Timer?

    var isActive: Bool { endDate != nil }
    var remaining: TimeInterval { max(0, endDate?.timeIntervalSinceNow ?? 0) }

    func start(minutes: Int) {
        endDate = Date().addingTimeInterval(TimeInterval(minutes) * 60)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func cancel() {
        endDate = nil
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard isActive, remaining <= 0 else { return }
        cancel()
        SoundPlayer.shared.play("achievement", volume: 0.6)
        ToastWindow.show(title: "Advancement Made!", subtitle: "Pomodoro complete")
        AppState.shared.effects.runPotionEffect()
    }
}
