import Foundation

/// Owns the focus-session state and countdown. Knows nothing about windows or
/// web views — it just transitions between modes and fires callbacks.
final class SessionController {

    enum Mode { case idle, active(until: Date), done }

    private(set) var mode: Mode = .idle
    let profile = Config.defaultProfile
    private var timer: Timer?

    /// Fired on a mode transition (idle → active → done).
    var onModeChange: (() -> Void)?
    /// Fired every second while active, so the countdown overlay can refresh.
    var onTick: (() -> Void)?

    var isActive: Bool { if case .active = mode { return true }; return false }

    /// Seconds left in the current session (0 if not active).
    var remaining: Int {
        if case .active(let end) = mode { return max(0, Int(end.timeIntervalSinceNow)) }
        return 0
    }

    func begin() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        // Resume a real-mode session that outlived a kill/relaunch, so killing the
        // process isn't an escape from the lock.
        if profile == .real, let end = Self.loadDeadline(), end > Date() {
            mode = .active(until: end)
        } else {
            mode = .idle
        }
        onModeChange?()
    }

    /// User pressed Start on the timer screen.
    func start(minutes: Int) { start(seconds: max(1, min(minutes, 24 * 60)) * 60) }

    /// Seconds-granularity entry point (used by the self-test for short runs;
    /// the page bridge also accepts a raw `seconds` for the same reason).
    func start(seconds: Int) {
        guard case .idle = mode else { return }
        let clamped = max(1, min(seconds, 24 * 60 * 60))
        let end = Date().addingTimeInterval(TimeInterval(clamped))
        mode = .active(until: end)
        if profile == .real { Self.saveDeadline(end) }
        onModeChange?()
    }

    private func tick() {
        guard case .active(let end) = mode else { return }
        if Date() >= end {
            Self.clearDeadline()
            if profile == .real { Self.markCompletedToday() }   // done for the day
            mode = .done
            onModeChange?()
        } else {
            onTick?()
        }
    }

    // MARK: - Per-day lock gate

    /// Local calendar day from the Mac's clock, e.g. "2026-06-18".
    private static func todayString() -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.timeZone = TimeZone.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
    /// True if a real session already ran to completion earlier today.
    static func alreadyCompletedToday() -> Bool {
        guard let s = try? String(contentsOf: Config.completedDayFile, encoding: .utf8) else { return false }
        return s.trimmingCharacters(in: .whitespacesAndNewlines) == todayString()
    }
    private static func markCompletedToday() {
        try? todayString().write(to: Config.completedDayFile, atomically: true, encoding: .utf8)
    }

    // MARK: - Persistence

    private struct State: Codable { let deadline: Date }

    private static func saveDeadline(_ date: Date) {
        try? JSONEncoder().encode(State(deadline: date)).write(to: Config.stateFile)
    }
    static func loadDeadline() -> Date? {
        guard let data = try? Data(contentsOf: Config.stateFile),
              let state = try? JSONDecoder().decode(State.self, from: data) else { return nil }
        return state.deadline
    }
    private static func clearDeadline() {
        try? FileManager.default.removeItem(at: Config.stateFile)
    }
}
