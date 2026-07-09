import Testing
@testable import PicoManim

private func approx(_ a: Double, _ b: Double, tolerance: Double = 1e-6) -> Bool {
    abs(a - b) <= tolerance
}

private func approx(_ a: Vec2, _ b: Vec2, tolerance: Double = 1e-6) -> Bool {
    approx(a.x, b.x, tolerance: tolerance) && approx(a.y, b.y, tolerance: tolerance)
}

@Suite("Number line")
struct NumberLineTests {
    @Test func spansLengthWithTicks() throws {
        let line = MobjectGroup.numberLine(range: -2...2, length: 8, tickSpacing: 1)
        // Base line + 5 ticks at -2, -1, 0, 1, 2.
        #expect(line.count == 6)
        let box = try #require(line.boundingBox)
        #expect(approx(box.min.x, -4))
        #expect(approx(box.max.x, 4))
    }

    @Test func degenerateRangeYieldsEmptyGroup() {
        let line = MobjectGroup.numberLine(range: 3...3)
        #expect(line.count == 0)
    }

    @Test func hugeOffsetRangesTerminate() {
        // At this magnitude value += spacing would round back to itself and
        // loop forever; index-based tick generation must terminate (the
        // ticks themselves may be dropped as unrepresentable).
        let line = MobjectGroup.numberLine(range: 1e16...(1e16 + 10), tickSpacing: 1)
        #expect(line.count >= 1)
    }
}

@Suite("Axes")
struct AxesTests {
    @Test func pointMapsValuesToScene() {
        let axes = Axes(x: -2...2, y: 0...4, size: Vec2(8, 4), at: .zero)
        #expect(approx(axes.point(x: 0, y: 2), Vec2(0, 0)))
        #expect(approx(axes.point(x: 2, y: 4), Vec2(4, 2)))
        #expect(approx(axes.point(x: -2, y: 0), Vec2(-4, -2)))
    }

    @Test func axesCrossAtZeroWhenIncluded() throws {
        let axes = Axes(x: -2...2, y: -1...3, size: Vec2(4, 4), at: .zero)
        // The x-axis line is the first mobject; it sits at value y == 0.
        let xAxis = axes.mobjects[0]
        let expectedY = axes.point(x: 0, y: 0).y
        #expect(approx(xAxis.center.y, expectedY, tolerance: 1e-6))
        // Tick counts: x has 5 (at integers -2...2), y has 5 (-1...3).
        #expect(axes.mobjects.count == 2 + 5 + 5)
    }

    @Test func axesHugTheEdgeWhenZeroExcluded() {
        let axes = Axes(x: 1...5, y: 2...6, size: Vec2(4, 4), at: .zero)
        let xAxis = axes.mobjects[0]
        // With zero below the y-range the x-axis sits on the bottom edge.
        #expect(approx(xAxis.center.y, -2, tolerance: 1e-6))
    }

    @Test func axesPinToTheZeroFacingEdge() {
        // Zero lies above/right of these all-negative ranges, so the axes
        // hug the top and right edges - the borders nearest the origin.
        let axes = Axes(x: (-5)...(-1), y: (-6)...(-2), size: Vec2(4, 4), at: .zero)
        let xAxis = axes.mobjects[0]
        #expect(approx(xAxis.center.y, 2, tolerance: 1e-6))
        let yAxis = axes.mobjects[1]
        #expect(approx(yAxis.center.x, 2, tolerance: 1e-6))
    }

    @Test func tinySpansMapExactly() {
        // A narrow-but-valid span must use its real extent, not a floored
        // minimum that would squash everything onto the lower edge.
        let axes = Axes(x: 0...1e-15, y: 0...1, size: Vec2(8, 4), at: .zero)
        #expect(approx(axes.point(x: 1e-15, y: 1), Vec2(4, 2)))
        #expect(approx(axes.point(x: 0, y: 0), Vec2(-4, -2)))
    }

    @Test func subnormalSpanMapsWithoutOverflow() {
        // A span so small that size / span overflows to +inf must still map
        // the endpoints to the area edges (via the divide-first fallback),
        // not to NaN.
        let tiny = Double.leastNonzeroMagnitude
        let axes = Axes(x: 0...tiny, y: 0...1, size: Vec2(8, 4), at: .zero)
        let hi = axes.point(x: tiny, y: 1)
        let lo = axes.point(x: 0, y: 0)
        #expect(hi.x.isFinite && hi.y.isFinite && lo.x.isFinite && lo.y.isFinite)
        #expect(approx(hi, Vec2(4, 2)))
        #expect(approx(lo, Vec2(-4, -2)))
    }

    @Test func independentTickSpacings() {
        let axes = Axes(
            x: -3...3, y: 0...9, size: Vec2(6, 6), at: .zero,
            xTickSpacing: 1, yTickSpacing: 3
        )
        // 2 axis lines + 7 x-ticks (-3...3) + 4 y-ticks (0, 3, 6, 9).
        #expect(axes.mobjects.count == 2 + 7 + 4)
    }

    @Test func plotFollowsTheFunction() throws {
        let axes = Axes(x: -2...2, y: 0...4, size: Vec2(8, 4), at: .zero)
        let graph = axes.plot({ $0 * $0 }, samples: 81)
        let box = try #require(graph.boundingBox)
        // x = ±2 -> y = 4 (scene y = 2); minimum at x = 0 -> y = 0 (scene -2).
        #expect(approx(box.min.y, -2, tolerance: 1e-3))
        #expect(approx(box.max.y, 2, tolerance: 1e-3))
        #expect(approx(box.min.x, -4, tolerance: 1e-3))
        #expect(approx(box.max.x, 4, tolerance: 1e-3))
    }

    @Test func plotSamplesTheRequestedDomain() throws {
        let axes = Axes(x: -2...2, y: 0...4, size: Vec2(8, 4), at: .zero)
        let graph = axes.plot({ $0 * $0 }, in: 0...1, samples: 11)
        let box = try #require(graph.boundingBox)
        #expect(approx(box.min.x, 0, tolerance: 1e-6))
        #expect(approx(box.max.x, 2, tolerance: 1e-6))
        // Polyline with 11 samples has 10 segments.
        #expect(graph.path.curveCount == 10)
    }

    @Test func plotSplitsAroundNonFiniteSamples() throws {
        let axes = Axes(x: -2...2, y: -4...4, size: Vec2(8, 4), at: .zero)
        // Samples land on x = -2, -1, 0, 1, 2; the pole at zero is skipped
        // and the two finite branches become separate subpaths.
        let graph = axes.plot({ 1 / $0 }, samples: 5)
        #expect(graph.path.subpaths.count == 2)
        let box = try #require(graph.boundingBox)
        #expect(box.min.x.isFinite && box.max.y.isFinite)
        // Highest finite sample is y = 1 at x = 1 (scene y = 0.5).
        #expect(approx(box.max.y, 0.5, tolerance: 1e-6))
    }

    @Test func plotDropsSamplesWhoseScenePointOverflows() throws {
        // On a unit y-range the factor is large enough that a finite-but-huge
        // sample maps to an overflowing scene point; it must split the branch
        // like a pole rather than poison the geometry with inf/NaN.
        let axes = Axes(x: 0...1, y: 0...1, size: Vec2(8, 5), at: .zero)
        let graph = axes.plot({ $0 == 0.5 ? Double.greatestFiniteMagnitude : 0.5 }, samples: 5)
        // Samples at x = 0, 0.25 and x = 0.75, 1 form two finite branches;
        // the overflowing sample at x = 0.5 separates them.
        #expect(graph.path.subpaths.count == 2)
        let box = try #require(graph.boundingBox)
        #expect(box.min.x.isFinite && box.min.y.isFinite && box.max.x.isFinite && box.max.y.isFinite)
        // An all-overflow plot has no drawable branch: empty path.
        let empty = axes.plot({ _ in Double.greatestFiniteMagnitude }, samples: 3)
        #expect(empty.path.isEmpty)
    }

    @Test func axesAnimateLikeAnyGroup() throws {
        var scene = ManimScene()
        let axes = Axes(x: 0...4, y: 0...4, size: Vec2(4, 4), at: .zero)
        scene.play(.create(axes.mobjects, duration: 1, lag: 0.01))
        #expect(scene.duration > 1)
        let end = scene.snapshot(at: scene.duration)
        #expect(end.count == axes.mobjects.count)
        #expect(end.allSatisfy { $0.strokeEnd == 1 })
    }
}
