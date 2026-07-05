/// A single animation applied to one mobject, built with the static
/// factories (`.create(_:)`, `.shift(_:by:)`, `.transform(_:into:)`, ...)
/// and scheduled with a ``ManimScene``'s `play` method.
///
/// Animations passed to one `play` call run in parallel; successive `play`
/// calls run one after another, exactly like Manim.
public struct ManimAnimation: Sendable {
    /// What the animation does to its target.
    public enum Kind: Sendable {
        /// Progressively draws the outline, then fades in the fill.
        case create
        /// Fades the mobject in, optionally sliding it by `shift`.
        case fadeIn(shift: Vec2)
        /// Fades the mobject out, optionally sliding it by `shift`.
        case fadeOut(shift: Vec2)
        /// Moves the mobject by a relative offset.
        case shift(by: Vec2)
        /// Moves the mobject to an absolute position.
        case move(to: Vec2)
        /// Rotates the mobject about its own center.
        case rotate(by: Double)
        /// Scales the mobject about its own center.
        case scale(by: Double)
        /// Morphs the mobject's shape and style into the target's.
        case transform(into: Mobject)
    }

    /// The target mobject as it was when the animation was built. The scene
    /// uses its ``Mobject/id`` to track the on-screen object, and its value
    /// to introduce mobjects that were never added or animated before.
    public var mobject: Mobject
    public var kind: Kind
    /// Duration in seconds.
    public var duration: Double
    public var rate: RateFunction

    public init(mobject: Mobject, kind: Kind, duration: Double = 1, rate: RateFunction = .smooth) {
        self.mobject = mobject
        self.kind = kind
        self.duration = duration
        self.rate = rate
    }

    // MARK: - Factories

    /// Draws the mobject's outline progressively, then fades in its fill.
    public static func create(
        _ mobject: Mobject,
        duration: Double = 1,
        rate: RateFunction = .smooth
    ) -> ManimAnimation {
        ManimAnimation(mobject: mobject, kind: .create, duration: duration, rate: rate)
    }

    /// Fades the mobject in, optionally sliding it in by `shift`.
    public static func fadeIn(
        _ mobject: Mobject,
        shift: Vec2 = .zero,
        duration: Double = 1,
        rate: RateFunction = .smooth
    ) -> ManimAnimation {
        ManimAnimation(mobject: mobject, kind: .fadeIn(shift: shift), duration: duration, rate: rate)
    }

    /// Fades the mobject out, optionally sliding it away by `shift`.
    public static func fadeOut(
        _ mobject: Mobject,
        shift: Vec2 = .zero,
        duration: Double = 1,
        rate: RateFunction = .smooth
    ) -> ManimAnimation {
        ManimAnimation(mobject: mobject, kind: .fadeOut(shift: shift), duration: duration, rate: rate)
    }

    /// Moves the mobject by `delta`.
    public static func shift(
        _ mobject: Mobject,
        by delta: Vec2,
        duration: Double = 1,
        rate: RateFunction = .smooth
    ) -> ManimAnimation {
        ManimAnimation(mobject: mobject, kind: .shift(by: delta), duration: duration, rate: rate)
    }

    /// Moves the mobject to `point`.
    public static func move(
        _ mobject: Mobject,
        to point: Vec2,
        duration: Double = 1,
        rate: RateFunction = .smooth
    ) -> ManimAnimation {
        ManimAnimation(mobject: mobject, kind: .move(to: point), duration: duration, rate: rate)
    }

    /// Rotates the mobject by `angle` radians about its own center.
    public static func rotate(
        _ mobject: Mobject,
        by angle: Double,
        duration: Double = 1,
        rate: RateFunction = .smooth
    ) -> ManimAnimation {
        ManimAnimation(mobject: mobject, kind: .rotate(by: angle), duration: duration, rate: rate)
    }

    /// Scales the mobject by `factor` about its own center.
    public static func scale(
        _ mobject: Mobject,
        by factor: Double,
        duration: Double = 1,
        rate: RateFunction = .smooth
    ) -> ManimAnimation {
        ManimAnimation(mobject: mobject, kind: .scale(by: factor), duration: duration, rate: rate)
    }

    /// Morphs the mobject into `target`, interpolating shape, placement,
    /// and style. The on-screen object keeps its original identity, so
    /// later animations can keep targeting the original mobject.
    public static func transform(
        _ mobject: Mobject,
        into target: Mobject,
        duration: Double = 1,
        rate: RateFunction = .smooth
    ) -> ManimAnimation {
        ManimAnimation(mobject: mobject, kind: .transform(into: target), duration: duration, rate: rate)
    }
}
