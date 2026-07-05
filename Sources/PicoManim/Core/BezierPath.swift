import Foundation

/// A vector path made of one or more subpaths, each a chain of cubic
/// Bézier curves. This mirrors Manim's `VMobject` representation: every
/// shape — including straight-edged polygons — is stored as cubics so that
/// any shape can morph smoothly into any other.
public struct BezierPath: Sendable, Hashable {
    /// A connected chain of cubic curves.
    public struct Subpath: Sendable, Hashable {
        public var curves: [CubicCurve]
        public var isClosed: Bool

        public init(curves: [CubicCurve], isClosed: Bool = false) {
            self.curves = curves
            self.isClosed = isClosed
        }
    }

    public var subpaths: [Subpath]

    public init(subpaths: [Subpath] = []) {
        self.subpaths = subpaths
    }

    /// Creates a single-subpath path.
    public init(curves: [CubicCurve], isClosed: Bool = false) {
        self.subpaths = [Subpath(curves: curves, isClosed: isClosed)]
    }

    /// Total number of curves across all subpaths.
    public var curveCount: Int {
        subpaths.reduce(0) { $0 + $1.curves.count }
    }

    public var isEmpty: Bool {
        subpaths.allSatisfy { $0.curves.isEmpty }
    }

    // MARK: - Construction

    /// An open polyline through `points`.
    public static func polyline(_ points: [Vec2]) -> BezierPath {
        guard points.count >= 2 else { return BezierPath() }
        var curves: [CubicCurve] = []
        curves.reserveCapacity(points.count - 1)
        for i in 0..<(points.count - 1) {
            curves.append(.line(from: points[i], to: points[i + 1]))
        }
        return BezierPath(curves: curves, isClosed: false)
    }

    /// A closed polygon through `points` (the closing edge is added
    /// automatically).
    public static func polygon(_ points: [Vec2]) -> BezierPath {
        guard points.count >= 3 else { return polyline(points) }
        var curves: [CubicCurve] = []
        curves.reserveCapacity(points.count)
        for i in 0..<points.count {
            curves.append(.line(from: points[i], to: points[(i + 1) % points.count]))
        }
        return BezierPath(curves: curves, isClosed: true)
    }

    /// A straight line segment.
    public static func line(from start: Vec2, to end: Vec2) -> BezierPath {
        BezierPath(curves: [.line(from: start, to: end)], isClosed: false)
    }

    /// A circular arc centered at `center`, from `startAngle` to `endAngle`
    /// (radians, counterclockwise when `endAngle > startAngle`).
    public static func arc(
        center: Vec2 = .zero,
        radius: Double,
        startAngle: Double,
        endAngle: Double
    ) -> BezierPath {
        let sweep = endAngle - startAngle
        guard abs(sweep) > 1e-9, radius > 0 else { return BezierPath() }
        // Use one cubic segment per (up to) 45 degrees of sweep.
        let segmentCount = max(1, Int(ceil(abs(sweep) / (Double.pi / 4) - 1e-9)))
        let delta = sweep / Double(segmentCount)
        // Standard cubic approximation of a circular arc segment.
        let k = (4.0 / 3.0) * tan(delta / 4)
        var curves: [CubicCurve] = []
        curves.reserveCapacity(segmentCount)
        for i in 0..<segmentCount {
            let a0 = startAngle + delta * Double(i)
            let a1 = a0 + delta
            let start = center + Vec2.direction(a0) * radius
            let end = center + Vec2.direction(a1) * radius
            // Tangent directions at the endpoints (counterclockwise).
            let t0 = Vec2(-Foundation.sin(a0), Foundation.cos(a0))
            let t1 = Vec2(-Foundation.sin(a1), Foundation.cos(a1))
            curves.append(CubicCurve(
                p0: start,
                c1: start + t0 * (k * radius),
                c2: end - t1 * (k * radius),
                p1: end
            ))
        }
        return BezierPath(curves: curves, isClosed: false)
    }

    /// A full circle of `radius` centered at `center`, built from 8 cubic
    /// segments so it morphs smoothly into other shapes.
    public static func circle(center: Vec2 = .zero, radius: Double) -> BezierPath {
        var path = arc(center: center, radius: radius, startAngle: 0, endAngle: 2 * Double.pi)
        for i in path.subpaths.indices {
            path.subpaths[i].isClosed = true
        }
        return path
    }

    /// An axis-aligned ellipse centered at `center`.
    public static func ellipse(center: Vec2 = .zero, width: Double, height: Double) -> BezierPath {
        var path = circle(center: .zero, radius: 1)
        let scale = Vec2(width / 2, height / 2)
        path = path.mapPoints { $0 * scale + center }
        return path
    }

    /// An axis-aligned rectangle centered at `center`.
    public static func rectangle(center: Vec2 = .zero, width: Double, height: Double) -> BezierPath {
        let w = width / 2
        let h = height / 2
        return polygon([
            Vec2(center.x + w, center.y + h),
            Vec2(center.x - w, center.y + h),
            Vec2(center.x - w, center.y - h),
            Vec2(center.x + w, center.y - h)
        ])
    }

    /// A regular polygon with `sides` vertices inscribed in a circle of
    /// `radius`, with the first vertex at `startAngle` radians.
    public static func regularPolygon(
        sides: Int,
        radius: Double,
        center: Vec2 = .zero,
        startAngle: Double = Double.pi / 2
    ) -> BezierPath {
        guard sides >= 3 else { return BezierPath() }
        let points = (0..<sides).map { i -> Vec2 in
            let angle = startAngle + 2 * Double.pi * Double(i) / Double(sides)
            return center + Vec2.direction(angle) * radius
        }
        return polygon(points)
    }

    // MARK: - Geometry

    /// Applies `transform` to every control point.
    public func mapPoints(_ transform: (Vec2) -> Vec2) -> BezierPath {
        var result = self
        for si in result.subpaths.indices {
            for ci in result.subpaths[si].curves.indices {
                var curve = result.subpaths[si].curves[ci]
                curve.p0 = transform(curve.p0)
                curve.c1 = transform(curve.c1)
                curve.c2 = transform(curve.c2)
                curve.p1 = transform(curve.p1)
                result.subpaths[si].curves[ci] = curve
            }
        }
        return result
    }

    /// The path with `transform` applied to every control point.
    public func transformed(by transform: Transform2D) -> BezierPath {
        mapPoints { transform.apply(to: $0) }
    }

    /// An approximate axis-aligned bounding box, computed by sampling each
    /// curve. Returns `nil` for an empty path. `samplesPerCurve` is clamped
    /// to at least 1.
    public func boundingBox(samplesPerCurve: Int = 8) -> (min: Vec2, max: Vec2)? {
        let samples = Swift.max(1, samplesPerCurve)
        var minPoint = Vec2(Double.infinity, Double.infinity)
        var maxPoint = Vec2(-Double.infinity, -Double.infinity)
        var found = false
        for subpath in subpaths {
            for curve in subpath.curves {
                for i in 0...samples {
                    let p = curve.point(at: Double(i) / Double(samples))
                    minPoint = Vec2(Swift.min(minPoint.x, p.x), Swift.min(minPoint.y, p.y))
                    maxPoint = Vec2(Swift.max(maxPoint.x, p.x), Swift.max(maxPoint.y, p.y))
                    found = true
                }
            }
        }
        return found ? (minPoint, maxPoint) : nil
    }

    /// The center of the bounding box, or the origin for an empty path.
    public var boundingBoxCenter: Vec2 {
        guard let box = boundingBox() else { return .zero }
        return (box.min + box.max) / 2
    }

    // MARK: - Partial paths

    /// The leading portion of the path, up to `proportion` (0...1) of its
    /// total curve count. Used for progressive "draw" animations.
    public func partial(upTo proportion: Double) -> BezierPath {
        let t = clamp(proportion, 0...1)
        if t >= 1 { return self }
        let total = curveCount
        guard total > 0, t > 0 else { return BezierPath() }
        var remaining = t * Double(total)
        var resultSubpaths: [Subpath] = []
        for subpath in subpaths {
            if remaining <= 0 { break }
            let count = Double(subpath.curves.count)
            if remaining >= count {
                resultSubpaths.append(subpath)
                remaining -= count
            } else {
                let whole = Int(remaining)
                let fraction = remaining - Double(whole)
                var curves = Array(subpath.curves.prefix(whole))
                if fraction > 1e-9, whole < subpath.curves.count {
                    curves.append(subpath.curves[whole].clipped(from: 0, to: fraction))
                }
                if !curves.isEmpty {
                    resultSubpaths.append(Subpath(curves: curves, isClosed: false))
                }
                remaining = 0
            }
        }
        return BezierPath(subpaths: resultSubpaths)
    }

    // MARK: - Alignment & interpolation

    /// Returns copies of `self` and `other` restructured to have the same
    /// number of subpaths and the same number of curves per subpath, so the
    /// two paths can be interpolated point-for-point.
    public func aligned(with other: BezierPath) -> (BezierPath, BezierPath) {
        var a = subpaths
        var b = other.subpaths

        func degenerateSubpath(near subpaths: [Subpath]) -> Subpath {
            let anchor = subpaths.reversed().first { !$0.curves.isEmpty }?.curves.last?.p1 ?? .zero
            return Subpath(
                curves: [CubicCurve(p0: anchor, c1: anchor, c2: anchor, p1: anchor)],
                isClosed: false
            )
        }

        while a.count < b.count { a.append(degenerateSubpath(near: a)) }
        while b.count < a.count { b.append(degenerateSubpath(near: b)) }

        for i in a.indices {
            let target = Swift.max(a[i].curves.count, b[i].curves.count)
            // Anchor an empty subpath at its counterpart's start so its
            // degenerate curves don't fly in from the origin during a morph.
            let anchorA = a[i].curves.first?.p0 ?? b[i].curves.first?.p0 ?? .zero
            let anchorB = b[i].curves.first?.p0 ?? a[i].curves.first?.p0 ?? .zero
            a[i] = a[i].subdividedEvenly(to: target, fallbackAnchor: anchorA)
            b[i] = b[i].subdividedEvenly(to: target, fallbackAnchor: anchorB)
        }
        return (BezierPath(subpaths: a), BezierPath(subpaths: b))
    }

    /// Interpolates between two structurally aligned paths (see
    /// ``aligned(with:)``). The inputs should have matching structure;
    /// subpaths and curves beyond the shorter path's count are dropped
    /// for 0 < t < 1.
    public static func interpolate(_ a: BezierPath, _ b: BezierPath, _ t: Double) -> BezierPath {
        if t <= 0 { return a }
        if t >= 1 { return b }
        var result: [Subpath] = []
        let subpathCount = Swift.min(a.subpaths.count, b.subpaths.count)
        result.reserveCapacity(subpathCount)
        for i in 0..<subpathCount {
            let sa = a.subpaths[i]
            let sb = b.subpaths[i]
            let curveCount = Swift.min(sa.curves.count, sb.curves.count)
            var curves: [CubicCurve] = []
            curves.reserveCapacity(curveCount)
            for j in 0..<curveCount {
                curves.append(.lerp(sa.curves[j], sb.curves[j], t))
            }
            result.append(Subpath(curves: curves, isClosed: sa.isClosed && sb.isClosed))
        }
        return BezierPath(subpaths: result)
    }
}

extension BezierPath.Subpath {
    /// The subpath with its curves subdivided so the total curve count is
    /// `target`. Extra splits are distributed as evenly as possible. An
    /// empty subpath is filled with degenerate point-curves placed at
    /// `fallbackAnchor` (callers pass the counterpart path's start point so
    /// morphs don't fly in from the origin).
    public func subdividedEvenly(to target: Int, fallbackAnchor: Vec2 = .zero) -> BezierPath.Subpath {
        let count = curves.count
        guard target > count else { return self }
        guard count > 0 else {
            let degenerate = CubicCurve(
                p0: fallbackAnchor, c1: fallbackAnchor, c2: fallbackAnchor, p1: fallbackAnchor
            )
            return BezierPath.Subpath(
                curves: Array(repeating: degenerate, count: target),
                isClosed: isClosed
            )
        }
        let base = target / count
        let remainder = target % count
        var result: [CubicCurve] = []
        result.reserveCapacity(target)
        for (i, curve) in curves.enumerated() {
            let pieces = base + (i < remainder ? 1 : 0)
            result.append(contentsOf: curve.subdivided(into: pieces))
        }
        return BezierPath.Subpath(curves: result, isClosed: isClosed)
    }
}
