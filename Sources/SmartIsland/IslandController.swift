import AppKit
import QuartzCore
import Combine
import SwiftUI

/// Owns the island panel and keeps it on the built-in display, centred under the notch.
@MainActor
final class IslandController {
    private let settings: AppSettings
    private let clock: ClockModel
    private let panel: IslandPanel
    private let state = IslandState()
    private var cancellables = Set<AnyCancellable>()

    init(settings: AppSettings) {
        self.settings = settings
        clock = ClockModel(settings: settings)
        panel = IslandPanel(contentRect: NSRect(
            x: 0, y: 0, width: IslandMetrics.fallbackNotchWidth, height: IslandMetrics.height
        ))

        let hosting = IslandHostingView(rootView: ClockView(clock: clock, settings: settings, state: state))
        hosting.sizingOptions = []
        hosting.onDragStarted = { [weak self] in self?.state.isDragging = true }
        hosting.onDragEnded = { [weak self] in self?.dragEnded() }
        hosting.onDoubleClick = { [weak self] in self?.settings.dragOffset = .zero }
        panel.contentView = hosting

        // Reposition when displays change (monitor plugged in/out, resolution, lid open/close),
        // after waking, and when the visibility or position settings change.
        let center = NSWorkspace.shared.notificationCenter
        let screens = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification).map { _ in () }
        let wake = center.publisher(for: NSWorkspace.didWakeNotification).map { _ in () }
        let screensWake = center.publisher(for: NSWorkspace.screensDidWakeNotification).map { _ in () }
        let settingsChanged = settings.$isVisible.map { _ in () }
            .merge(with: settings.$dragOffset.map { _ in () })
        Publishers.Merge4(screens, wake, screensWake, settingsChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.update() } }
            .store(in: &cancellables)
    }

    /// Shows the island in the right place, or hides it if it's switched off or the lid is closed.
    func update(animated: Bool = true) {
        guard settings.isVisible, let screen = Self.builtInScreen() else {
            hide(animated: animated)
            return
        }
        let target = frame(on: screen)
        if !panel.isVisible {
            // Appear in place with a fade rather than sliding in from elsewhere.
            panel.setFrame(target, display: true)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        // Glide to the new spot (e.g. snapping back under the notch) and fade in if needed.
        animate(duration: animated ? 0.3 : 0) {
            if self.panel.frame != target { self.panel.animator().setFrame(target, display: true) }
            if self.panel.alphaValue < 1 { self.panel.animator().alphaValue = 1 }
        }
    }

    private func hide(animated: Bool) {
        guard panel.isVisible else { return }
        animate(duration: animated ? 0.2 : 0) {
            self.panel.animator().alphaValue = 0
        } completion: { [weak self] in
            guard let self, !self.settings.isVisible || Self.builtInScreen() == nil else { return }
            self.panel.orderOut(nil)
        }
    }

    private func animate(duration: TimeInterval, _ changes: @escaping () -> Void, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1)
            context.allowsImplicitAnimation = true
            changes()
        } completionHandler: {
            MainActor.assumeIsolated { completion?() }
        }
    }

    /// The MacBook's own display, ignoring external monitors even if one is the main display.
    static func builtInScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return CGDisplayIsBuiltin(number.uint32Value) != 0
        }
    }

    /// Where the island sits when docked: from the top edge of the screen, covering the notch,
    /// down to the clock strip just below it, a little wider than the notch.
    private func dockedFrame(on screen: NSScreen) -> NSRect {
        let full = screen.frame
        var notchWidth = IslandMetrics.fallbackNotchWidth
        var notchHeight: CGFloat = 0
        if screen.safeAreaInsets.top > 0 {
            notchHeight = screen.safeAreaInsets.top
            if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
                let measured = full.width - left.width - right.width
                if measured > 80, measured < 400 { notchWidth = measured }
            }
        } else {
            // No notch: hang below the menu bar instead.
            notchHeight = full.maxY - screen.visibleFrame.maxY
        }
        let bodyWidth = notchWidth + IslandMetrics.sideOverhang * 2
        // The window also includes the shoulder curves either side of the body.
        let windowWidth = bodyWidth + IslandMetrics.shoulderRadius * 2
        let windowHeight = notchHeight + IslandMetrics.height
        return NSRect(
            x: (full.midX - windowWidth / 2).rounded(),
            y: full.maxY - windowHeight,
            width: windowWidth,
            height: windowHeight
        )
    }

    /// Docked frame plus the saved drag offset, kept fully on the built-in screen.
    private func frame(on screen: NSScreen) -> NSRect {
        var frame = dockedFrame(on: screen)
        frame.origin.x += settings.dragOffset.width
        frame.origin.y += settings.dragOffset.height
        let bounds = screen.frame
        frame.origin.x = min(max(frame.origin.x, bounds.minX), bounds.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, bounds.minY), bounds.maxY - frame.height)
        return frame
    }

    private func dragEnded() {
        state.isDragging = false
        guard let screen = Self.builtInScreen() else { return }
        let docked = dockedFrame(on: screen)
        var dx = panel.frame.origin.x - docked.origin.x
        var dy = panel.frame.origin.y - docked.origin.y
        if hypot(dx, dy) < IslandMetrics.snapDistance {
            dx = 0
            dy = 0
        }
        settings.dragOffset = CGSize(width: dx, height: dy)
        update()
    }
}
