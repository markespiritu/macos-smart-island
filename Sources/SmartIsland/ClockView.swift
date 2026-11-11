import SwiftUI

enum IslandMetrics {
    /// Height of the clock strip below the notch, in points. Tune this first if it feels too big or small.
    static let height: CGFloat = 26
    /// Notch width/height used when they can't be detected (e.g. a Mac without a notch).
    static let fallbackNotchWidth: CGFloat = 185
    /// How far the island extends past each side of the notch.
    static let sideOverhang: CGFloat = 10
    static let fontSize: CGFloat = 15
    /// Radius used for both the shoulder curves (where the island meets the menu bar) and the bottom corners.
    static let cornerRadius: CGFloat = 32
    static var shoulderRadius: CGFloat { cornerRadius }
    static var bottomRadius: CGFloat { cornerRadius }
    /// Dropping the island within this many points of the notch snaps it back.
    static let snapDistance: CGFloat = 24
}

/// Live state of the island that the view animates on.
final class IslandState: ObservableObject {
    @Published var isDragging = false
}

/// The black island with the time in it.
struct ClockView: View {
    @ObservedObject var clock: ClockModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var state: IslandState

    var body: some View {
        let docked = settings.dragOffset == .zero && !state.isDragging
        ZStack(alignment: .bottom) {
            IslandShape(
                shoulderRadius: IslandMetrics.shoulderRadius,
                bottomRadius: IslandMetrics.bottomRadius,
                stripHeight: IslandMetrics.height,
                docked: docked ? 1 : 0
            )
            .fill(Color.black)

            Text(clock.text)
                .font(.system(size: IslandMetrics.fontSize, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.35), value: clock.text)
                .frame(maxWidth: .infinity)
                .frame(height: IslandMetrics.height)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: docked)
    }
}

/// Notch-style shape.
///
/// Docked: one continuous black shape that starts at the top edge of the screen (covering the
/// notch), flares out with concave "shoulders" where it meets the menu bar, and ends in big soft
/// bottom corners just below the notch, so the clock looks like part of the notch.
/// Floating: morphs into a plain pill the height of the clock strip, at the bottom of the window.
struct IslandShape: Shape {
    var shoulderRadius: CGFloat
    var bottomRadius: CGFloat
    var stripHeight: CGFloat
    /// 1 = docked under the notch, 0 = floating pill. Animatable, so the shape morphs smoothly.
    var docked: CGFloat

    var animatableData: CGFloat {
        get { docked }
        set { docked = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let shoulder = shoulderRadius * docked
        // The body spans [left, right]; the shoulder strips either side are only filled when docked.
        let left = shoulderRadius
        let right = w - shoulderRadius
        // Floating: the top drops down to the strip, leaving the area above it transparent.
        let top = (h - stripHeight) * (1 - docked)
        let bodyHeight = h - top
        let floatingRadius = stripHeight / 2
        let bottom = min(bottomRadius * docked + floatingRadius * (1 - docked), bodyHeight / 2, (right - left) / 2)
        let topConvex = min(floatingRadius, bodyHeight / 2) * (1 - docked)

        var p = Path()
        if shoulder > 0.01 {
            p.move(to: CGPoint(x: left - shoulder, y: top))
            p.addCorner(to: CGPoint(x: left, y: top + shoulder), corner: CGPoint(x: left, y: top))
        } else {
            p.move(to: CGPoint(x: left + topConvex, y: top))
            p.addCorner(to: CGPoint(x: left, y: top + topConvex), corner: CGPoint(x: left, y: top))
        }
        p.addLine(to: CGPoint(x: left, y: h - bottom))
        p.addCorner(to: CGPoint(x: left + bottom, y: h), corner: CGPoint(x: left, y: h))
        p.addLine(to: CGPoint(x: right - bottom, y: h))
        p.addCorner(to: CGPoint(x: right, y: h - bottom), corner: CGPoint(x: right, y: h))
        if shoulder > 0.01 {
            p.addLine(to: CGPoint(x: right, y: top + shoulder))
            p.addCorner(to: CGPoint(x: right + shoulder, y: top), corner: CGPoint(x: right, y: top))
        } else {
            p.addLine(to: CGPoint(x: right, y: top + topConvex))
            p.addCorner(to: CGPoint(x: right - topConvex, y: top), corner: CGPoint(x: right, y: top))
        }
        p.closeSubpath()
        return p
    }
}

private extension Path {
    /// Rounds a 90° corner with a circular arc (cubic Bézier approximation), going from the
    /// current point to `end`, bending around `corner`. Unlike a quad curve, the bend is spread
    /// evenly, so neighbouring curves meet cleanly.
    mutating func addCorner(to end: CGPoint, corner: CGPoint) {
        guard let start = currentPoint else { return }
        let k: CGFloat = 0.5523 // 4/3 * (sqrt(2) - 1)
        let c1 = CGPoint(x: start.x + (corner.x - start.x) * k, y: start.y + (corner.y - start.y) * k)
        let c2 = CGPoint(x: end.x + (corner.x - end.x) * k, y: end.y + (corner.y - end.y) * k)
        addCurve(to: end, control1: c1, control2: c2)
    }
}
