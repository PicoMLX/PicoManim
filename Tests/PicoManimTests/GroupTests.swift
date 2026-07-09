import Testing
@testable import PicoManim

private func approx(_ a: Double, _ b: Double, tolerance: Double = 1e-6) -> Bool {
    abs(a - b) <= tolerance
}

private func approx(_ a: Vec2, _ b: Vec2, tolerance: Double = 1e-6) -> Bool {
    approx(a.x, b.x, tolerance: tolerance) && approx(a.y, b.y, tolerance: tolerance)
}

@Suite("Mobject layout")
struct MobjectLayoutTests {
    @Test func widthHeightAndCenter() throws {
        let square = Mobject.square(sideLength: 2, at: Vec2(3, -1))
        #expect(approx(square.width, 2))
        #expect(approx(square.height, 2))
        #expect(approx(square.center, Vec2(3, -1)))
        #expect(approx(square.edge(Vec2(1, 0)), Vec2(4, -1)))
        #expect(approx(square.edge(Vec2(0, 1)), Vec2(3, 0)))
    }

    @Test func nextToPlacesWithGap() {
        let square = Mobject.square(sideLength: 2)
        let dot = Mobject.dot()
        let below = dot.nextTo(square, direction: Vec2(0, -1), gap: 0.25)
        #expect(approx(below.center, Vec2(0, -(1 + 0.08 + 0.25)), tolerance: 1e-3))
        let right = dot.nextTo(square, direction: Vec2(1, 0), gap: 0.5)
        #expect(approx(right.center, Vec2(1 + 0.08 + 0.5, 0), tolerance: 1e-3))
    }
}

@Suite("Mobject groups")
struct MobjectGroupTests {
    @Test func boundingBoxIsTheUnion() throws {
        let group = MobjectGroup(
            Mobject.dot(at: Vec2(0, 0)),
            Mobject.dot(at: Vec2(4, 2))
        )
        let box = try #require(group.boundingBox)
        #expect(approx(box.min, Vec2(-0.08, -0.08), tolerance: 0.01))
        #expect(approx(box.max, Vec2(4.08, 2.08), tolerance: 0.01))
        #expect(approx(group.center, Vec2(2, 1), tolerance: 0.01))
    }

    @Test func arrangedLaysOutInARow() {
        let group = MobjectGroup(
            Mobject.square(sideLength: 2),
            Mobject.square(sideLength: 2),
            Mobject.square(sideLength: 2)
        ).arranged(spacing: 0.5)
        #expect(approx(group[0].center, Vec2(0, 0)))
        #expect(approx(group[1].center, Vec2(2.5, 0)))
        #expect(approx(group[2].center, Vec2(5, 0)))
    }

    @Test func movedRecentersTheGroup() {
        let group = MobjectGroup(
            Mobject.dot(at: Vec2(0, 0)),
            Mobject.dot(at: Vec2(2, 0))
        ).moved(to: Vec2(10, 5))
        #expect(approx(group.center, Vec2(10, 5), tolerance: 0.01))
        // Relative layout preserved.
        #expect(approx(group[1].center - group[0].center, Vec2(2, 0), tolerance: 0.01))
    }

    @Test func rotatedOrbitsChildrenAboutGroupCenter() {
        let group = MobjectGroup(
            Mobject.dot(at: Vec2(1, 0)),
            Mobject.dot(at: Vec2(-1, 0))
        ).rotated(by: .pi / 2)
        #expect(approx(group[0].position, Vec2(0, 1), tolerance: 1e-9))
        #expect(approx(group[1].position, Vec2(0, -1), tolerance: 1e-9))
        #expect(approx(group[0].transform.rotation, .pi / 2))
    }

    @Test func scaledMovesChildrenRadially() {
        let group = MobjectGroup(
            Mobject.dot(at: Vec2(1, 0)),
            Mobject.dot(at: Vec2(-1, 0))
        ).scaled(by: 2)
        #expect(approx(group[0].position, Vec2(2, 0), tolerance: 1e-9))
        #expect(approx(group[1].position, Vec2(-2, 0), tolerance: 1e-9))
        #expect(approx(group[0].transform.scale.x, 2))
    }
}

@Suite("Group animations")
struct GroupAnimationTests {
    @Test func groupShiftMovesEveryChild() throws {
        var scene = ManimScene()
        let group = MobjectGroup(
            Mobject.dot(at: Vec2(0, 0)),
            Mobject.dot(at: Vec2(1, 0))
        )
        scene.add(group.mobjects)
        scene.play(.shift(group, by: Vec2(0, 2), duration: 1, rate: .linear))

        let end = scene.snapshot(at: 1)
        #expect(end.count == 2)
        #expect(approx(end[0].position, Vec2(0, 2)))
        #expect(approx(end[1].position, Vec2(1, 2)))
    }

    @Test func lagStaggersChildren() throws {
        var scene = ManimScene()
        let group = MobjectGroup(
            Mobject.circle(radius: 1, at: Vec2(-2, 0)),
            Mobject.circle(radius: 1, at: Vec2(2, 0))
        )
        scene.play(.create(group, duration: 1, lag: 0.5, rate: .linear))
        #expect(approx(scene.duration, 1.5))

        let early = scene.snapshot(at: 0.25)
        #expect(approx(early[0].strokeEnd, 0.25))
        #expect(early[1].strokeEnd == 0) // not started yet

        let end = scene.snapshot(at: 1.5)
        #expect(end[0].strokeEnd == 1)
        #expect(end[1].strokeEnd == 1)
    }

    @Test func groupRotationOrbitsAlongAnArc() throws {
        var scene = ManimScene()
        let group = MobjectGroup(
            Mobject.dot(at: Vec2(1, 0)),
            Mobject.dot(at: Vec2(-1, 0))
        )
        scene.add(group.mobjects)
        scene.play(.rotate(group, by: .pi, duration: 1, rate: .linear))

        // Midway the child is a quarter-turn around the pivot — on the arc,
        // not on the chord through the center.
        let mid = try #require(scene.snapshot(at: 0.5).first)
        #expect(approx(mid.position, Vec2(0, 1), tolerance: 1e-9))

        let end = scene.snapshot(at: 1)
        #expect(approx(end[0].position, Vec2(-1, 0), tolerance: 1e-9))
        #expect(approx(end[0].transform.rotation, .pi))
        #expect(approx(end[1].position, Vec2(1, 0), tolerance: 1e-9))
    }

    @Test func groupScaleMovesChildrenRadially() throws {
        var scene = ManimScene()
        let group = MobjectGroup(
            Mobject.dot(at: Vec2(1, 0)),
            Mobject.dot(at: Vec2(-1, 0))
        )
        scene.add(group.mobjects)
        scene.play(.scale(group, by: 3, duration: 1, rate: .linear))

        let mid = scene.snapshot(at: 0.5)
        #expect(approx(mid[0].position, Vec2(2, 0), tolerance: 1e-9))
        let end = scene.snapshot(at: 1)
        #expect(approx(end[0].position, Vec2(3, 0), tolerance: 1e-9))
        #expect(approx(end[0].transform.scale.x, 3))
    }

    @Test func rotateAboutPivotForSingleMobject() throws {
        var scene = ManimScene()
        let dot = Mobject.dot(at: Vec2(1, 0))
        scene.add(dot)
        scene.play(.rotate(dot, by: .pi, about: .zero, duration: 1, rate: .linear))
        let end = try #require(scene.snapshot(at: 1).first)
        #expect(approx(end.position, Vec2(-1, 0), tolerance: 1e-9))
    }

    @Test func groupTransformPairsAndFadesExtras() throws {
        var scene = ManimScene()
        let source = MobjectGroup(
            Mobject.circle(radius: 1, at: Vec2(-2, 0)),
            Mobject.square(sideLength: 1, at: Vec2(2, 0))
        )
        scene.add(source.mobjects)
        let target = MobjectGroup(
            Mobject.triangle(radius: 1, at: Vec2(0, 0))
        )
        scene.play(.transform(source, into: target, duration: 1))

        let end = scene.snapshot(at: 1)
        #expect(end.count == 2)
        // First child morphed into the triangle (same visual center as the
        // target, original identity preserved)...
        #expect(end[0].id == source[0].id)
        #expect(approx(end[0].center, target[0].center, tolerance: 1e-6))
        // ...and the unmatched source faded out.
        #expect(end[1].opacity == 0)
    }

    @Test func mixedGroupAndSingleAnimationsPlayTogether() throws {
        var scene = ManimScene()
        let group = MobjectGroup(Mobject.dot(at: Vec2(0, 0)))
        let solo = Mobject.dot(at: Vec2(5, 5))
        scene.add(group.mobjects)
        scene.add(solo)
        scene.play(
            .shift(group, by: Vec2(1, 0), duration: 1, rate: .linear),
            .shift(solo, by: Vec2(0, 1), duration: 1, rate: .linear)
        )
        let end = scene.snapshot(at: 1)
        #expect(approx(end[0].position, Vec2(1, 0)))
        #expect(approx(end[1].position, Vec2(5, 6)))
    }

    @Test func diagonalEdgeAndNextToStayOnTheBox() {
        let square = Mobject.square(sideLength: 2) // half-extents (1, 1)
        // A unit diagonal and a Manim-style (1, 1) both name the corner.
        let unitDiagonal = Vec2(1, 1) / Vec2(1, 1).length
        #expect(approx(square.edge(unitDiagonal), Vec2(1, 1)))
        #expect(approx(square.edge(Vec2(1, 1)), Vec2(1, 1)))
        // Corner-to-corner placement instead of an overlapping interior hit.
        let neighbor = Mobject.square(sideLength: 2).nextTo(square, direction: Vec2(1, 1), gap: 0)
        #expect(approx(neighbor.center, Vec2(2, 2)))
        // Non-square boxes still name the true corner (Manim's get_corner).
        let wide = Mobject.rectangle(width: 10, height: 2)
        #expect(approx(wide.edge(Vec2(1, 1)), Vec2(5, 1)))
        #expect(approx(wide.edge(unitDiagonal), Vec2(5, 1)))
    }

    @Test func groupMoveResolvesFromTheLiveCenter() throws {
        var scene = ManimScene()
        let group = MobjectGroup(
            Mobject.dot(at: Vec2(-1, 0)),
            Mobject.dot(at: Vec2(1, 0))
        )
        scene.add(group.mobjects)
        scene.play(.shift(group, by: Vec2(10, 0)))
        // The factory's group value is now stale; the move must still land
        // the *live* group center on the requested point.
        scene.play(.move(group, to: .zero))
        let end = scene.snapshot(at: scene.duration)
        #expect(approx(end[0].position, Vec2(-1, 0)))
        #expect(approx(end[1].position, Vec2(1, 0)))
    }

    @Test func groupRotateOrbitsTheLivePivot() throws {
        var scene = ManimScene()
        let group = MobjectGroup(
            Mobject.dot(at: Vec2(1, 0)),
            Mobject.dot(at: Vec2(3, 0))
        )
        scene.add(group.mobjects)
        scene.play(.shift(group, by: Vec2(2, 0))) // live centers: 3 and 5
        scene.play(.rotate(group, by: .pi))
        // A half turn about the live center (4, 0) swaps the dots; the
        // stale pre-shift pivot (2, 0) would fling them to x = 1 and -1.
        let end = scene.snapshot(at: scene.duration)
        #expect(approx(end[0].position, Vec2(5, 0), tolerance: 1e-9))
        #expect(approx(end[1].position, Vec2(3, 0), tolerance: 1e-9))
    }

    @Test func twoGroupsInOnePlayResolveIndependentCenters() throws {
        // The per-play center cache is keyed by member ids, so two distinct
        // groups rotated in the same call must each pivot about their own
        // live center rather than colliding on a shared cache entry.
        var scene = ManimScene()
        let left = MobjectGroup(Mobject.dot(at: Vec2(-3, 0)), Mobject.dot(at: Vec2(-1, 0)))
        let right = MobjectGroup(Mobject.dot(at: Vec2(1, 0)), Mobject.dot(at: Vec2(3, 0)))
        scene.add(left.mobjects)
        scene.add(right.mobjects)
        scene.play(.rotate(left, by: .pi), .rotate(right, by: .pi))
        let end = scene.snapshot(at: scene.duration)
        // Left pivots about (-2, 0): dots swap to -1 and -3.
        #expect(approx(end[0].position, Vec2(-1, 0), tolerance: 1e-9))
        #expect(approx(end[1].position, Vec2(-3, 0), tolerance: 1e-9))
        // Right pivots about (2, 0): dots swap to 3 and 1.
        #expect(approx(end[2].position, Vec2(3, 0), tolerance: 1e-9))
        #expect(approx(end[3].position, Vec2(1, 0), tolerance: 1e-9))
    }

    @Test func delayedSiblingDrivesThePropertyAfterItsDelay() throws {
        var scene = ManimScene()
        let dot = Mobject.dot(at: .zero)
        scene.add(dot)
        var delayed = ManimAnimation.move(dot, to: Vec2(5, 0), duration: 1, rate: .linear)
        delayed.delay = 1
        // The delayed animation is listed *first*; chronological entry
        // ordering must still let it win once its delay elapses instead of
        // being overwritten by the already-finished sibling.
        scene.play([delayed, .move(dot, to: Vec2(1, 0), duration: 1, rate: .linear)])
        let mid = try #require(scene.snapshot(at: 1.5).first)
        #expect(approx(mid.position, Vec2(2.5, 0)))
        let end = try #require(scene.snapshot(at: 2).first)
        #expect(approx(end.position, Vec2(5, 0)))
        // The build cursor agrees with the timeline, so follow-up plays
        // start from the delayed animation's end, not the sibling's.
        #expect(approx(scene.state(of: dot)?.position ?? Vec2(-1, -1), Vec2(5, 0)))
    }
}
