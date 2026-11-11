import AppKit
import SwiftUI

enum IslandMetrics {
    /// Height of the clock strip below the notch, in points. Tune this first if it feels too big or small.
    static let height: CGFloat = 34
    /// Notch width/height used when they can't be detected (e.g. a Mac without a notch).
    static let fallbackNotchWidth: CGFloat = 185
    /// How far the island extends past each side of the notch.
    static let sideOverhang: CGFloat = 10
    static let fontSize: CGFloat = 15
    /// How dark the glass is tinted (0 = clear glass, 1 = solid black).
    static let glassTint: Double = 0.75
    /// Opacity the glass fades to at the very bottom of the island (1 = no fade).
    static let glassFadeEndOpacity: Double = 0.1
    /// Size of the outward (concave) curve where the island meets the menu bar.
    static let shoulderRadius: CGFloat = 14
    /// Radius of the bottom corners.
    static let bottomRadius: CGFloat = 22
    /// Hold this key to grab the island (drag to move, double-click to reset); otherwise clicks
    /// pass through to whatever is underneath. ⌘-drag is how macOS moves background windows.
    static let moveModifier: NSEvent.ModifierFlags = .command
    /// Dropping the island within this many points of the notch snaps it back.
    static let snapDistance: CGFloat = 24
}

/// Live state of the island that the view animates on.
final class IslandState: ObservableObject {
    @Published var isDragging = false
    /// ⌘ is held with the pointer over the island, so it can be dragged.
    @Published var isGrabbable = false
}

/// The black island with the time in it.
struct ClockView: View {
    @ObservedObject var clock: ClockModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var state: IslandState

    private var useGlass: Bool { settings.useGlass }

    var body: some View {
        let docked = settings.dragOffset == .zero && !state.isDragging
        ZStack(alignment: .bottom) {
            IslandBackground(
                shape: IslandShape(
                    shoulderRadius: IslandMetrics.shoulderRadius,
                    bottomRadius: IslandMetrics.bottomRadius,
                    stripHeight: IslandMetrics.height,
                    docked: docked ? 1 : 0
                ),
                glass: settings.useGlass
            )

            Text(clock.text)
                .font(.system(size: IslandMetrics.fontSize, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(AnyShapeStyle(.white))
                .shadow(color: .black.opacity(0.5), radius: 2)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.35), value: clock.text)
                .frame(maxWidth: .infinity)
                .frame(height: IslandMetrics.height)
        }
        // Subtle outline while the island can be grabbed (⌘ held over it).
        .overlay {
            IslandShape(
                shoulderRadius: IslandMetrics.shoulderRadius,
                bottomRadius: IslandMetrics.bottomRadius,
                stripHeight: IslandMetrics.height,
                docked: docked ? 1 : 0
            )
            .stroke(Color.white.opacity(state.isGrabbable ? 0.25 : 0), lineWidth: 1)
            .animation(.easeOut(duration: 0.15), value: state.isGrabbable)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: docked)
        .animation(.smooth(duration: 0.3), value: settings.useGlass)
    }
}

/// Fills the island shape with either solid black (blends with the notch) or Liquid Glass
/// (lets whatever is underneath show through).
struct IslandBackground: View {
    var shape: IslandShape
    var glass: Bool

    var body: some View {
        if glass {
            ZStack {
                // Glass + tint, fading from fully opaque at the bottom of the menu bar to nearly
                // clear at the bottom of the island (the floating pill fades the same way).
                ZStack {
                    if #available(macOS 26, *) {
                        Color.clear.glassEffect(.regular, in: shape)
                    } else {
                        Color.clear.background(.ultraThinMaterial, in: shape)
                    }
                    shape.fill(Color.black.opacity(IslandMetrics.glassTint))
                }
                .compositingGroup()
                .mask {
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            Rectangle().frame(height: max(0, geo.size.height - shape.stripHeight))
                            LinearGradient(
                                colors: [.white, .white.opacity(IslandMetrics.glassFadeEndOpacity)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                    }
                }
                // The part level with the menu bar (everything above the clock strip, including
                // the shoulders) stays solid black so it blends with the notch; only the strip
                // below the menu bar is glass.
                shape.fill(Color.black)
                    .mask(alignment: .top) {
                        GeometryReader { geo in
                            Rectangle().frame(height: max(0, geo.size.height - shape.stripHeight))
                        }
                    }
            }
        } else {
            shape.fill(Color.black)
        }
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
