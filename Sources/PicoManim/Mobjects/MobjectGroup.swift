import Foundation

// MARK: - Mobject layout helpers

extension Mobject {
    /// The world-space bounding box, or `nil` for an empty path.
    public var boundingBox: (min: Vec2, max: Vec2)? {
        worldPath.boundingBox()
    }

    /// Bounding-box width in scene units (0 for an empty path).
    public var width: Double {
        guard let box = boundingBox else { return 0 }
        return box.max.x - box.min.x
    }

    /// Bounding-box height in scene units (0 for an empty path).
    public var height: Double {
        guard let box = boundingBox else { return 0 }
        return box.max.y - box.min.y
    }

    /// The bounding-box center in scene coordinates. Unlike ``position``
    /// (the local origin), this is the visual center even for shapes whose
    /// path is not origin-centered.
    public var center: Vec2 {
        guard let box = boundingBox else { return position }
        return (box.min + box.max) / 2
    }

    /// The Manim-style critical point of the bounding box in `direction`:
    /// each axis independently picks the box's min, center, or max by the
    /// sign of that direction component. `Vec2(1, 0)` is the middle of the
    /// right edge; any diagonal - `Vec2(1, 1)` or a unit vector alike -
    /// is the true corner, even for non-square boxes. Magnitude is ignored.
    public func edge(_ direction: Vec2) -> Vec2 {
        guard let box = boundingBox else { return position }
        let half = (box.max - box.min) / 2
        func component(_ d: Double, _ h: Double) -> Double {
            d > 0 ? h : (d < 0 ? -h : 0)
        }
        return center + Vec2(component(direction.x, half.x), component(direction.y, half.y))
    }

    /// A copy placed beside `other`: shifted so this mobject's facing edge
    /// point (``edge(_:)`` toward `other`) sits `gap` away from `other`'s
    /// edge point along `direction`. Cardinal directions line boxes up
    /// side by side; diagonals meet corner to corner.
    public func nextTo(_ other: Mobject, direction: Vec2 = Vec2(1, 0), gap: Double = 0.25) -> Mobject {
        let magnitude = direction.length
        guard magnitude > 0 else { return self }
        let unit = direction / magnitude
        let anchor = other.edge(direction) + unit * gap
        return shifted(by: anchor - edge(-direction))
    }
}

// MARK: - MobjectGroup

/// A collection of mobjects treated as one unit for layout and animation —
/// the PicoManim counterpart of Manim's `VGroup`.
///
/// Groups are a build-time convenience: they carry no identity of their
/// own. Group transformations return repositioned copies of the children
/// (identity preserved), and group animations expand into per-child
/// animations when played:
///
/// ```swift
/// let row = MobjectGroup(a, b, c).arranged(spacing: 0.5)
/// scene.play(.create(row, lag: 0.2))       // staggered draw-in
/// scene.play(.rotate(row, by: .pi / 2))    // orbits about the group center
/// ```
public struct MobjectGroup: Sendable {
    public var mobjects: [Mobject]

    public init(_ mobjects: [Mobject]) {
        self.mobjects = mobjects
    }

    public init(_ mobjects: Mobject...) {
        self.init(mobjects)
    }

    public var count: Int { mobjects.count }

    public subscript(index: Int) -> Mobject { mobjects[index] }

    /// The union of the children's world-space bounding boxes.
    public var boundingBox: (min: Vec2, max: Vec2)? {
        var minPoint = Vec2(Double.infinity, Double.infinity)
        var maxPoint = Vec2(-Double.infinity, -Double.infinity)
        var found = false
        for mobject in mobjects {
            guard let box = mobject.boundingBox else { continue }
            minPoint = Vec2(Swift.min(minPoint.x, box.min.x), Swift.min(minPoint.y, box.min.y))
            maxPoint = Vec2(Swift.max(maxPoint.x, box.max.x), Swift.max(maxPoint.y, box.max.y))
            found = true
        }
        return found ? (minPoint, maxPoint) : nil
    }

    /// The group's bounding-box center, or the origin for an empty group.
    public var center: Vec2 {
        guard let box = boundingBox else { return .zero }
        return (box.min + box.max) / 2
    }

    /// A copy with every child shifted by `delta`.
    public func shifted(by delta: Vec2) -> MobjectGroup {
        MobjectGroup(mobjects.map { $0.shifted(by: delta) })
    }

    /// A copy translated so the group's bounding-box center lands on `point`.
    public func moved(to point: Vec2) -> MobjectGroup {
        shifted(by: point - center)
    }

    /// A copy rotated by `angle` radians about the group's center: each
    /// child rotates in place and its position orbits the group center.
    public func rotated(by angle: Double) -> MobjectGroup {
        let pivot = center
        return MobjectGroup(mobjects.map { child in
            var copy = child.rotated(by: angle)
            copy.position = pivot + (child.position - pivot).rotated(by: angle)
            return copy
        })
    }

    /// A copy scaled by `factor` about the group's center: each child
    /// scales in place and its position moves radially.
    public func scaled(by factor: Double) -> MobjectGroup {
        let pivot = center
        return MobjectGroup(mobjects.map { child in
            var copy = child.scaled(by: factor)
            copy.position = pivot + (child.position - pivot) * factor
            return copy
        })
    }

    /// A copy with the children laid out in a row along `direction`, each
    /// placed ``Mobject/nextTo(_:direction:gap:)`` the previous one. The
    /// first child keeps its position; use ``moved(to:)`` to recenter.
    public func arranged(direction: Vec2 = Vec2(1, 0), spacing: Double = 0.25) -> MobjectGroup {
        guard var previous = mobjects.first else { return self }
        var result = [previous]
        for child in mobjects.dropFirst() {
            let placed = child.nextTo(previous, direction: direction, gap: spacing)
            result.append(placed)
            previous = placed
        }
        return MobjectGroup(result)
    }
}

// MARK: - Group animations

/// Staggers a list of animations: child i starts `i * lag` seconds into
/// the play group (Manim's lag_ratio).
private func staggered(_ animations: [ManimAnimation], lag: Double) -> [ManimAnimation] {
    guard lag > 0 else { return animations }
    return animations.enumerated().map { index, animation in
        var copy = animation
        copy.delay = Double(index) * lag
        return copy
    }
}

// Group factories mirror the single-mobject ones but return one animation
// per child, ready to pass to `play`. They live on `[ManimAnimation]` so
// leading-dot syntax resolves where a `play` call expects an animation
// list: `scene.play(.create(group, lag: 0.2))`.
extension Array where Element == ManimAnimation {
    /// Draws each child in; `lag` staggers their start times.
    public static func create(
        _ group: MobjectGroup,
        duration: Double = 1,
        lag: Double = 0,
        rate: RateFunction = .smooth
    ) -> [ManimAnimation] {
        staggered(
            group.mobjects.map { ManimAnimation.create($0, duration: duration, rate: rate) },
            lag: lag
        )
    }

    /// Fades each child in; `lag` staggers their start times.
    public static func fadeIn(
        _ group: MobjectGroup,
        shift: Vec2 = .zero,
        duration: Double = 1,
        lag: Double = 0,
        rate: RateFunction = .smooth
    ) -> [ManimAnimation] {
        staggered(
            group.mobjects.map {
                ManimAnimation.fadeIn($0, shift: shift, duration: duration, rate: rate)
            },
            lag: lag
        )
    }

    /// Fades each child out; `lag` staggers their start times.
    public static func fadeOut(
        _ group: MobjectGroup,
        shift: Vec2 = .zero,
        duration: Double = 1,
        lag: Double = 0,
        rate: RateFunction = .smooth
    ) -> [ManimAnimation] {
        staggered(
            group.mobjects.map {
                ManimAnimation.fadeOut($0, shift: shift, duration: duration, rate: rate)
            },
            lag: lag
        )
    }

    /// Moves every child by `delta`.
    public static func shift(
        _ group: MobjectGroup,
        by delta: Vec2,
        duration: Double = 1,
        rate: RateFunction = .smooth
    ) -> [ManimAnimation] {
        group.mobjects.map { ManimAnimation.shift($0, by: delta, duration: duration, rate: rate) }
    }

    /// Moves the group so its bounding-box center lands on `point`. The
    /// center is resolved from the scene's live state when played, so the
    /// group ends on `point` even after earlier animations moved it.
    public static func move(
        _ group: MobjectGroup,
        to point: Vec2,
        duration: Double = 1,
        rate: RateFunction = .smooth
    ) -> [ManimAnimation] {
        group.mobjects.map {
            ManimAnimation(
                mobject: $0,
                kind: .groupMove(to: point, members: group.mobjects),
                duration: duration,
                rate: rate
            )
        }
    }

    /// Rotates the group about its bounding-box center: each child rotates
    /// in place while its position orbits the pivot along a circular arc.
    /// The pivot is the group's *live* center when played, not the center
    /// of the value this factory captured.
    public static func rotate(
        _ group: MobjectGroup,
        by angle: Double,
        duration: Double = 1,
        rate: RateFunction = .smooth
    ) -> [ManimAnimation] {
        group.mobjects.map {
            ManimAnimation(
                mobject: $0,
                kind: .groupRotate(by: angle, members: group.mobjects),
                duration: duration,
                rate: rate
            )
        }
    }

    /// Scales the group about its bounding-box center: each child scales in
    /// place while its position moves radially. The pivot is the group's
    /// *live* center when played.
    public static func scale(
        _ group: MobjectGroup,
        by factor: Double,
        duration: Double = 1,
        rate: RateFunction = .smooth
    ) -> [ManimAnimation] {
        group.mobjects.map {
            ManimAnimation(
                mobject: $0,
                kind: .groupScale(by: factor, members: group.mobjects),
                duration: duration,
                rate: rate
            )
        }
    }

    /// Morphs one group into another. Children pair up by index; extra
    /// sources fade out and extra targets fade in.
    public static func transform(
        _ group: MobjectGroup,
        into target: MobjectGroup,
        duration: Double = 1,
        rate: RateFunction = .smooth
    ) -> [ManimAnimation] {
        var animations: [ManimAnimation] = []
        let paired = Swift.min(group.count, target.count)
        for i in 0..<paired {
            animations.append(
                ManimAnimation.transform(group[i], into: target[i], duration: duration, rate: rate)
            )
        }
        for i in paired..<group.count {
            animations.append(ManimAnimation.fadeOut(group[i], duration: duration, rate: rate))
        }
        for i in paired..<target.count {
            animations.append(ManimAnimation.fadeIn(target[i], duration: duration, rate: rate))
        }
        return animations
    }
}
