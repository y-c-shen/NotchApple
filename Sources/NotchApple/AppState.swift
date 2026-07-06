import Foundation

enum AppleMode: String, CaseIterable {
    case particles
    case pomodoro
    case blocker

    var label: String {
        switch self {
        case .particles: return "Default"
        case .pomodoro: return "Pomodoro"
        case .blocker: return "Blocker"
        }
    }

    var next: AppleMode {
        let all = AppleMode.allCases
        let index = all.firstIndex(of: self)!
        return all[(index + 1) % all.count]
    }
}

final class AppState {
    static let shared = AppState()
    let effects = EffectController()
    let pomodoro = PomodoroController()
    let blocker = DistractionBlocker()

    var mode: AppleMode {
        get { AppleMode(rawValue: UserDefaults.standard.string(forKey: "mode") ?? "") ?? .particles }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "mode") }
    }

    var pomodoroMinutes: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: "pomodoroMinutes")
            return stored == 0 ? 25 : stored
        }
        set { UserDefaults.standard.set(min(120, max(5, newValue)), forKey: "pomodoroMinutes") }
    }

    static let defaultBlockedDomains = [
        "facebook.com", "instagram.com", "twitter.com", "x.com",
        "tiktok.com", "reddit.com", "youtube.com",
    ]

    var blockedDomains: [String] {
        get { UserDefaults.standard.stringArray(forKey: "blockedDomains") ?? Self.defaultBlockedDomains }
        set { UserDefaults.standard.set(newValue, forKey: "blockedDomains") }
    }

    func cycleMode() {
        mode = mode.next
        // Leaving blocker mode lifts the block — no mystery "why is reddit down".
        if mode != .blocker { blocker.setActive(false) }
    }

    func handleEat() {
        switch mode {
        case .particles:
            break
        case .pomodoro:
            pomodoro.start(minutes: pomodoroMinutes)
        case .blocker:
            blocker.setActive(!blocker.isActive)
        }
        effects.runPotionEffect()
    }
}
