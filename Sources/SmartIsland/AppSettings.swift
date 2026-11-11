import Combine
import Foundation

/// User preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key {
        static let isVisible = "isVisible"
        static let use24Hour = "use24Hour"
        static let showSeconds = "showSeconds"
        static let useGlass = "useGlass"
        static let dragOffsetX = "dragOffsetX"
        static let dragOffsetY = "dragOffsetY"
    }

    private let defaults: UserDefaults

    @Published var isVisible: Bool {
        didSet { defaults.set(isVisible, forKey: Key.isVisible) }
    }

    @Published var use24Hour: Bool {
        didSet { defaults.set(use24Hour, forKey: Key.use24Hour) }
    }

    @Published var showSeconds: Bool {
        didSet { defaults.set(showSeconds, forKey: Key.showSeconds) }
    }

    /// Liquid Glass island instead of solid black (macOS 26+).
    @Published var useGlass: Bool {
        didSet { defaults.set(useGlass, forKey: Key.useGlass) }
    }

    /// Offset of the island from its docked spot under the notch. `.zero` means docked.
    @Published var dragOffset: CGSize {
        didSet {
            defaults.set(Double(dragOffset.width), forKey: Key.dragOffsetX)
            defaults.set(Double(dragOffset.height), forKey: Key.dragOffsetY)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.isVisible: true,
            Key.use24Hour: true,
            Key.showSeconds: false,
            Key.useGlass: true,
        ])
        isVisible = defaults.bool(forKey: Key.isVisible)
        use24Hour = defaults.bool(forKey: Key.use24Hour)
        showSeconds = defaults.bool(forKey: Key.showSeconds)
        useGlass = defaults.bool(forKey: Key.useGlass)
        dragOffset = CGSize(
            width: defaults.double(forKey: Key.dragOffsetX),
            height: defaults.double(forKey: Key.dragOffsetY)
        )
    }
}
