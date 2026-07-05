import Testing
@testable import PicoManim

private func approx(_ a: Double, _ b: Double, tolerance: Double = 1e-9) -> Bool {
    abs(a - b) <= tolerance
}

private func approx(_ a: Vec2, _ b: Vec2, tolerance: Double = 1e-9) -> Bool {
    approx(a.x, b.x, tolerance: tolerance) && approx(a.y, b.y, tolerance: tolerance)
}

@Suite("Cubic curves")
struct CubicCurveTests {
    @Test func linePointIsLinear() {
        let curve = CubicCurve.line(from: Vec2(0, 0), to: Vec2(4, 2))
        #expect(approx(curve.point(at: 0), Vec2(0, 0)))
        #expect(approx(curve.point(at: 0.5), Vec2(2, 1)))
        #expect(approx(curve.point(at: 1), Vec2(4, 2)))
    }

    @Test func splitPreservesGeometry() {
        let curve = CubicCurve(
            p0: Vec2(0, 0), c1: Vec2(1, 2), c2: Vec2(3, -1), p1: Vec2(4, 0)
        )
        let (head, tail) = curve.split(at: 0.3)
        #expect(approx(head.p1, tail.p0))
        #expect(approx(head.p0, curve.p0))
        #expect(approx(tail.p1, curve.p1))
        // A point in the head half maps to the original curve.
        #expect(approx(head.point(at: 0.5), curve.point(at: 0.15), tolerance: 1e-9))
        // A point in the tail half maps to the original curve.
        #expect(approx(tail.point(at: 0.5), curve.point(at: 0.3 + 0.7 * 0.5), tolerance: 1e-9))
    }

    @Test func subdividedPreservesEndpointsAndCount() {
        let curve = CubicCurve(
            p0: Vec2(0, 0), c1: Vec2(1, 2), c2: Vec2(3, -1), p1: Vec2(4, 0)
        )
        let pieces = curve.subdivided(into: 3)
        #expect(pieces.count == 3)
        #expect(approx(pieces[0].p0, curve.p0))
        #expect(approx(pieces[2].p1, curve.p1))
        #expect(approx(pieces[0].p1, pieces[1].p0))
        #expect(approx(pieces[1].p1, pieces[2].p0))
        #expect(approx(pieces[1].p0, curve.point(at: 1.0 / 3.0), tolerance: 1e-9))
    }
}

@Suite("Bezier paths")
struct BezierPathTests {
    @Test func circleBoundsMatchRadius() throws {
        let path = BezierPath.circle(radius: 1.5)
        let box = try #require(path.boundingBox())
        #expect(approx(box.max.x, 1.5, tolerance: 0.01))
        #expect(approx(box.max.y, 1.5, tolerance: 0.01))
        #expect(approx(box.min.x, -1.5, tolerance: 0.01))
        #expect(approx(box.min.y, -1.5, tolerance: 0.01))
        #expect(path.subpaths.count == 1)
        #expect(path.subpaths[0].isClosed)
        #expect(path.curveCount == 8)
    }

    @Test func polygonIsClosedPolylineIsOpen() {
        let triangle = BezierPath.polygon([Vec2(0, 0), Vec2(1, 0), Vec2(0, 1)])
        #expect(triangle.subpaths[0].isClosed)
        #expect(triangle.curveCount == 3)

        let open = BezierPath.polyline([Vec2(0, 0), Vec2(1, 0), Vec2(0, 1)])
        #expect(!open.subpaths[0].isClosed)
        #expect(open.curveCount == 2)
    }

    @Test func rectangleBounds() throws {
        let path = BezierPath.rectangle(width: 4, height: 2)
        let box = try #require(path.boundingBox())
        #expect(approx(box.min.x, -2))
        #expect(approx(box.max.x, 2))
        #expect(approx(box.min.y, -1))
        #expect(approx(box.max.y, 1))
    }

    @Test func arcEndpointsLieOnCircle() throws {
        let path = BezierPath.arc(radius: 2, startAngle: 0, endAngle: .pi)
        let first = try #require(path.subpaths.first?.curves.first)
        let last = try #require(path.subpaths.first?.curves.last)
        #expect(approx(first.p0, Vec2(2, 0), tolerance: 1e-9))
        #expect(approx(last.p1, Vec2(-2, 0), tolerance: 1e-9))
        // Half circle at 45 degrees per segment.
        #expect(path.curveCount == 4)
    }

    @Test func negativeSweepArcRunsClockwise() throws {
        let path = BezierPath.arc(radius: 1, startAngle: .pi / 2, endAngle: 0)
        let first = try #require(path.subpaths.first?.curves.first)
        let last = try #require(path.subpaths.first?.curves.last)
        #expect(approx(first.p0, Vec2(0, 1), tolerance: 1e-9))
        #expect(approx(last.p1, Vec2(1, 0), tolerance: 1e-9))
        // Midpoint of the quarter sweep stays on the circle.
        let mid = first.point(at: 0.5)
        #expect(approx(mid.length, 1, tolerance: 1e-3))
    }

    @Test func partialHalfOfSquareKeepsTwoEdges() {
        let square = BezierPath.rectangle(width: 2, height: 2)
        let half = square.partial(upTo: 0.5)
        #expect(half.curveCount == 2)
        #expect(!half.subpaths[0].isClosed)
    }

    @Test func partialSplitsBoundaryCurve() throws {
        let square = BezierPath.rectangle(width: 2, height: 2)
        let partial = square.partial(upTo: 0.375) // 1.5 of 4 curves
        #expect(partial.curveCount == 2)
        let lastPoint = try #require(partial.subpaths.first?.curves.last?.p1)
        let expected = square.subpaths[0].curves[1].point(at: 0.5)
        #expect(approx(lastPoint, expected, tolerance: 1e-9))
    }

    @Test func partialZeroAndOne() {
        let circle = BezierPath.circle(radius: 1)
        #expect(circle.partial(upTo: 0).isEmpty)
        #expect(circle.partial(upTo: 1).curveCount == circle.curveCount)
    }

    @Test func alignmentEqualizesCurveCounts() {
        let circle = BezierPath.circle(radius: 1)      // 8 curves
        let square = BezierPath.rectangle(width: 2, height: 2) // 4 curves
        let (a, b) = circle.aligned(with: square)
        #expect(a.curveCount == 8)
        #expect(b.curveCount == 8)
        #expect(a.subpaths.count == b.subpaths.count)
    }

    @Test func alignmentPadsMissingSubpaths() {
        let one = BezierPath.circle(radius: 1)
        let two = BezierPath(subpaths: [
            BezierPath.Subpath(curves: [.line(from: Vec2(0, 0), to: Vec2(1, 0))]),
            BezierPath.Subpath(curves: [.line(from: Vec2(0, 1), to: Vec2(1, 1))])
        ])
        let (a, b) = one.aligned(with: two)
        #expect(a.subpaths.count == 2)
        #expect(b.subpaths.count == 2)
        for i in 0..<2 {
            #expect(a.subpaths[i].curves.count == b.subpaths[i].curves.count)
        }
    }

    @Test func interpolationEndpointsMatchInputs() throws {
        let circle = BezierPath.circle(radius: 1)
        let square = BezierPath.rectangle(width: 2, height: 2)
        let (a, b) = circle.aligned(with: square)
        let atStart = BezierPath.interpolate(a, b, 0)
        let atEnd = BezierPath.interpolate(a, b, 1)
        let startBox = try #require(atStart.boundingBox())
        let aBox = try #require(a.boundingBox())
        #expect(approx(startBox.min, aBox.min))
        let endBox = try #require(atEnd.boundingBox())
        let bBox = try #require(b.boundingBox())
        #expect(approx(endBox.max, bBox.max))
    }

    @Test func transformedByOffsetMovesBounds() throws {
        let path = BezierPath.circle(radius: 1)
            .transformed(by: Transform2D(translation: Vec2(3, -2)))
        let box = try #require(path.boundingBox())
        #expect(approx((box.min.x + box.max.x) / 2, 3, tolerance: 1e-6))
        #expect(approx((box.min.y + box.max.y) / 2, -2, tolerance: 1e-6))
    }
}
