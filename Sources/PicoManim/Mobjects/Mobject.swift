import Foundation

/// A "mathematical object": a vector shape plus its visual style and
/// placement, the PicoManim equivalent of Manim's `VMobject`.
///
/// `Mobject` is a value type, but every mobject carries a stable identity
/// (``id``) assigned when it is first created. Copies made by the fluent
/// modifiers (``fill(_:opacity:)``, ``shifted(by:)``, ...) keep the same
/// identity, which is how a ``ManimScene`` knows that successive animations
/// target the same on-screen object.
public struct Mobject: Identifiable, Sendable, Hashable {
    /// A stable identity shared by all copies of a mobject.
    public struct ID: Hashable, Sendable {
        let raw: UUID

        init() {
            self.raw = UUID()
        }
    }

    public let id: ID

    /// The shape's outline in local coordinates (typically centered on the
    /// local origin).
    public var path: BezierPath

    /// Placement of the local coordinate system in the scene. Rotation and
    /// scale are applied about the local origin, so shapes rotate and scale
    /// around their own centers.
    public var transform: Transform2D

    /// Outline color. The alpha component controls stroke opacity.
    public var strokeColor: ManimColor
    /// Outline width, in Manim stroke units (4 is the familiar default;
    /// 100 stroke units equal one scene unit on screen).
    public var strokeWidth: Double
    /// Interior color. The alpha component controls fill opacity; most
    /// shapes default to a fully transparent fill.
    public var fillColor: ManimColor

    /// Master opacity multiplier applied to both stroke and fill.
    /// Fade animations drive this value.
    public var opacity: Double

    /// The visible portion of the outline, as fractions of the full path.
    /// `Create` animates ``strokeEnd`` from 0 to 1.
    public var strokeStart: Double
    public var strokeEnd: Double

    /// Extra multiplier on fill opacity used by draw-in animations so the
    /// fill can fade in after the outline is drawn.
    public var fillOpacityFactor: Double

    public init(
        path: BezierPath,
        transform: Transform2D = .identity,
        strokeColor: ManimColor = .white,
        strokeWidth: Double = 4,
        fillColor: ManimColor = ManimColor.white.withOpacity(0)
    ) {
        self.id = ID()
        self.path = path
        self.transform = transform
        self.strokeColor = strokeColor
        self.strokeWidth = Swift.max(0, strokeWidth)
        self.fillColor = fillColor
        self.opacity = 1
        self.strokeStart = 0
        self.strokeEnd = 1
        self.fillOpacityFactor = 1
    }

    // MARK: - Derived geometry

    /// The mobject's position in the scene (its local origin).
    public var position: Vec2 {
        get { transform.translation }
        set { transform.translation = newValue }
    }

    /// The path with the mobject's transform applied, in scene coordinates.
    public var worldPath: BezierPath {
        path.transformed(by: transform)
    }

    /// Effective stroke alpha after all opacity factors, clamped to 0...1
    /// so out-of-range inputs (e.g. custom rate functions that overshoot)
    /// can't reach the renderer.
    public var effectiveStrokeAlpha: Double {
        clamp(strokeColor.alpha * opacity, 0...1)
    }

    /// Effective fill alpha after all opacity factors, clamped to 0...1.
    public var effectiveFillAlpha: Double {
        clamp(fillColor.alpha * fillOpacityFactor * opacity, 0...1)
    }

    // MARK: - Fluent modifiers (identity-preserving)

    /// A copy with a new stroke color and, optionally, stroke width.
    public func stroke(_ color: ManimColor, width: Double? = nil) -> Mobject {
        var copy = self
        copy.strokeColor = color
        if let width { copy.strokeWidth = Swift.max(0, width) }
        return copy
    }

    /// A copy filled with `color` at the given opacity.
    public func fill(_ color: ManimColor, opacity: Double = 1) -> Mobject {
        var copy = self
        copy.fillColor = color.withOpacity(opacity)
        return copy
    }

    /// A copy with its master opacity set to `value`.
    public func withOpacity(_ value: Double) -> Mobject {
        var copy = self
        copy.opacity = value
        return copy
    }

    /// A copy moved to `point`.
    public func moved(to point: Vec2) -> Mobject {
        var copy = self
        copy.transform.translation = point
        return copy
    }

    /// A copy shifted by `delta`.
    public func shifted(by delta: Vec2) -> Mobject {
        var copy = self
        copy.transform.translation += delta
        return copy
    }

    /// A copy rotated by `angle` radians about its own center.
    public func rotated(by angle: Double) -> Mobject {
        var copy = self
        copy.transform.rotation += angle
        return copy
    }

    /// A copy scaled by `factor` about its own center.
    public func scaled(by factor: Double) -> Mobject {
        var copy = self
        copy.transform.scale *= factor
        return copy
    }
}
