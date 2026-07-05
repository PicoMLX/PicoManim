/// A single cubic Bézier curve defined by four control points.
public struct CubicCurve: Sendable, Hashable {
    public var p0: Vec2
    public var c1: Vec2
    public var c2: Vec2
    public var p1: Vec2

    public init(p0: Vec2, c1: Vec2, c2: Vec2, p1: Vec2) {
        self.p0 = p0
        self.c1 = c1
        self.c2 = c2
        self.p1 = p1
    }

    /// A cubic curve that traces the straight line from `start` to `end`,
    /// with control points at the one-third points so that `point(at:)`
    /// moves linearly along the segment.
    public static func line(from start: Vec2, to end: Vec2) -> CubicCurve {
        CubicCurve(
            p0: start,
            c1: Vec2.lerp(start, end, 1.0 / 3.0),
            c2: Vec2.lerp(start, end, 2.0 / 3.0),
            p1: end
        )
    }

    /// Evaluates the curve at parameter `t` in 0...1.
    public func point(at t: Double) -> Vec2 {
        let u = 1 - t
        let a = u * u * u
        let b = 3 * u * u * t
        let c = 3 * u * t * t
        let d = t * t * t
        return p0 * a + c1 * b + c2 * c + p1 * d
    }

    /// Splits the curve at parameter `t` using de Casteljau's algorithm,
    /// returning the two halves.
    public func split(at t: Double) -> (CubicCurve, CubicCurve) {
        let q0 = Vec2.lerp(p0, c1, t)
        let q1 = Vec2.lerp(c1, c2, t)
        let q2 = Vec2.lerp(c2, p1, t)
        let r0 = Vec2.lerp(q0, q1, t)
        let r1 = Vec2.lerp(q1, q2, t)
        let s = Vec2.lerp(r0, r1, t)
        return (
            CubicCurve(p0: p0, c1: q0, c2: r0, p1: s),
            CubicCurve(p0: s, c1: r1, c2: q2, p1: p1)
        )
    }

    /// The sub-curve covering parameters `a...b` of this curve.
    public func clipped(from a: Double, to b: Double) -> CubicCurve {
        let a = clamp(a, 0...1)
        let b = clamp(b, a...1)
        if a <= 0 && b >= 1 { return self }
        if a >= 1 {
            return CubicCurve(p0: p1, c1: p1, c2: p1, p1: p1)
        }
        let tail = a <= 0 ? self : split(at: a).1
        // Remap b into the tail's parameter space.
        let tb = (b - a) / (1 - a)
        if tb >= 1 { return tail }
        return tail.split(at: tb).0
    }

    /// Splits the curve into `count` sub-curves of equal parameter span.
    public func subdivided(into count: Int) -> [CubicCurve] {
        guard count > 1 else { return [self] }
        var pieces: [CubicCurve] = []
        pieces.reserveCapacity(count)
        for i in 0..<count {
            let t0 = Double(i) / Double(count)
            let t1 = Double(i + 1) / Double(count)
            pieces.append(clipped(from: t0, to: t1))
        }
        return pieces
    }

    /// Component-wise linear interpolation between two curves.
    public static func lerp(_ a: CubicCurve, _ b: CubicCurve, _ t: Double) -> CubicCurve {
        CubicCurve(
            p0: Vec2.lerp(a.p0, b.p0, t),
            c1: Vec2.lerp(a.c1, b.c1, t),
            c2: Vec2.lerp(a.c2, b.c2, t),
            p1: Vec2.lerp(a.p1, b.p1, t)
        )
    }
}
