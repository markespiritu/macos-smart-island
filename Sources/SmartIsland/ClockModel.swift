import AppKit
import Combine

/// Produces the formatted time string, updating exactly on each minute (or second) boundary.
@MainActor
final class ClockModel: ObservableObject {
    @Published private(set) var text = ""

    private let settings: AppSettings
    private let formatter = DateFormatter()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(settings: AppSettings) {
        self.settings = settings
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Re-render when the format settings change.
        settings.$use24Hour.combineLatest(settings.$showSeconds)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } }
            .store(in: &cancellables)

        // Re-sync after sleep, manual clock changes, or travelling across time zones.
        let wake = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
        let clockChanged = NotificationCenter.default.publisher(for: .NSSystemClockDidChange)
        let timeZoneChanged = NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
        Publishers.Merge3(wake, clockChanged, timeZoneChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } }
            .store(in: &cancellables)

        refresh()
    }

    func refresh() {
        NSTimeZone.resetSystemTimeZone()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = pattern
        text = formatter.string(from: Date())
        scheduleNextTick()
    }

    private var pattern: String {
        switch (settings.use24Hour, settings.showSeconds) {
        case (true, false): return "HH:mm"
        case (true, true): return "HH:mm:ss"
        case (false, false): return "h:mm a"
        case (false, true): return "h:mm:ss a"
        }
    }

    /// One-shot timer aligned to the next boundary, so the display never drifts.
    private func scheduleNextTick() {
        timer?.invalidate()
        let step: TimeInterval = settings.showSeconds ? 1 : 60
        let now = Date().timeIntervalSinceReferenceDate
        let next = (floor(now / step) + 1) * step + 0.005
        let timer = Timer(fire: Date(timeIntervalSinceReferenceDate: next), interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
