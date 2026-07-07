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
        // With zero outside the y-range the x-axis sits on the bottom edge.
        #expect(approx(xAxis.center.y, -2, tolerance: 1e-6))
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
