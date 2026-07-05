import Testing
@testable import PicoManim

private func approx(_ a: Double, _ b: Double, tolerance: Double = 1e-9) -> Bool {
    abs(a - b) <= tolerance
}

private func approx(_ a: Vec2, _ b: Vec2, tolerance: Double = 1e-9) -> Bool {
    approx(a.x, b.x, tolerance: tolerance) && approx(a.y, b.y, tolerance: tolerance)
}

@Suite("Scene timeline")
struct SceneTimelineTests {
    @Test func durationAccumulatesAcrossPlaysAndWaits() {
        var scene = ManimScene()
        let circle = Mobject.circle(radius: 1)
        let square = Mobject.square()
        scene.play(.create(circle, duration: 1))
        scene.wait(0.5)
        scene.play(
            .shift(circle, by: Vec2(1, 0), duration: 1),
            .create(square, duration: 2)
        )
        #expect(approx(scene.duration, 3.5))
    }

    @Test func addShowsMobjectAtCurrentTime() throws {
        var scene = ManimScene()
        scene.wait(1)
        let dot = Mobject.dot()
        scene.add(dot)
        #expect(approx(scene.duration, 1))

        let before = try #require(scene.snapshot(at: 0.5).first { $0.id == dot.id })
        #expect(before.opacity == 0)
        let after = try #require(scene.snapshot(at: 1).first { $0.id == dot.id })
        #expect(after.opacity == 1)
    }

    @Test func createRevealsStrokeThenFill() throws {
        var scene = ManimScene()
        let circle = Mobject.circle(radius: 1).fill(.blue, opacity: 0.8)
        scene.play(.create(circle, duration: 2, rate: .linear))

        let start = try #require(scene.snapshot(at: 0).first)
        #expect(start.strokeEnd == 0)
        #expect(start.effectiveFillAlpha == 0)

        let quarter = try #require(scene.snapshot(at: 0.5).first)
        #expect(approx(quarter.strokeEnd, 0.25))
        #expect(quarter.fillOpacityFactor == 0) // fill starts after half

        let threeQuarters = try #require(scene.snapshot(at: 1.5).first)
        #expect(approx(threeQuarters.strokeEnd, 0.75))
        #expect(approx(threeQuarters.fillOpacityFactor, 0.5))

        let end = try #require(scene.snapshot(at: 2).first)
        #expect(end.strokeEnd == 1)
        #expect(approx(end.effectiveFillAlpha, 0.8))
    }

    @Test func shiftInterpolatesPosition() throws {
        var scene = ManimScene()
        let dot = Mobject.dot(at: Vec2(1, 1))
        scene.add(dot)
        scene.play(.shift(dot, by: Vec2(2, 0), duration: 1, rate: .linear))

        let mid = try #require(scene.snapshot(at: 0.5).first)
        #expect(approx(mid.position, Vec2(2, 1)))
        let end = try #require(scene.snapshot(at: 1).first)
        #expect(approx(end.position, Vec2(3, 1)))
    }

    @Test func sequentialAnimationsCompose() throws {
        var scene = ManimScene()
        let dot = Mobject.dot(at: .zero)
        scene.add(dot)
        scene.play(.shift(dot, by: Vec2(1, 0), duration: 1))
        scene.play(.shift(dot, by: Vec2(0, 2), duration: 1))
        scene.play(.move(dot, to: Vec2(-1, -1), duration: 1))

        let afterSecond = try #require(scene.snapshot(at: 2).first)
        #expect(approx(afterSecond.position, Vec2(1, 2)))
        let final = try #require(scene.snapshot(at: 3).first)
        #expect(approx(final.position, Vec2(-1, -1)))
    }

    @Test func parallelAnimationsOnSameMobjectComposePerProperty() throws {
        var scene = ManimScene()
        let square = Mobject.square()
        scene.add(square)
        scene.play(
            .rotate(square, by: .pi, duration: 1, rate: .linear),
            .scale(square, by: 2, duration: 1, rate: .linear),
            .shift(square, by: Vec2(1, 0), duration: 1, rate: .linear)
        )

        let mid = try #require(scene.snapshot(at: 0.5).first)
        #expect(approx(mid.transform.rotation, .pi / 2))
        #expect(approx(mid.transform.scale.x, 1.5))
        #expect(approx(mid.position, Vec2(0.5, 0)))

        let end = try #require(scene.snapshot(at: 1).first)
        #expect(approx(end.transform.rotation, .pi))
        #expect(approx(end.transform.scale.x, 2))
        #expect(approx(end.position, Vec2(1, 0)))
    }

    @Test func parallelAnimationsOnSamePropertyDoNotJump() throws {
        var scene = ManimScene()
        let dot = Mobject.dot(at: .zero)
        scene.add(dot)
        scene.play(
            .shift(dot, by: Vec2(1, 0), duration: 1, rate: .linear),
            .shift(dot, by: Vec2(0, 2), duration: 1, rate: .linear)
        )

        // No jump at the start of the group: both siblings start from the
        // pre-group state.
        let start = try #require(scene.snapshot(at: 0).first)
        #expect(approx(start.position, Vec2(0, 0)))
        // Same-property siblings don't blend; the later one wins...
        let mid = try #require(scene.snapshot(at: 0.5).first)
        #expect(approx(mid.position, Vec2(0, 1)))
        // ...through to its own end pole.
        let end = try #require(scene.snapshot(at: 1).first)
        #expect(approx(end.position, Vec2(0, 2)))
    }

    @Test func createAfterFadeOutRevealsAgain() throws {
        var scene = ManimScene()
        let circle = Mobject.circle(radius: 1)
        scene.play(.create(circle, duration: 1))
        scene.play(.fadeOut(circle, duration: 1))
        scene.play(.create(circle, duration: 1))

        // create is a revealing animation: it restores opacity while it
        // redraws the outline.
        let end = try #require(scene.snapshot(at: 3).first)
        #expect(end.opacity == 1)
        #expect(end.strokeEnd == 1)
    }

    @Test func zeroShiftFadeComposesWithParallelMotion() throws {
        var scene = ManimScene()
        let dot = Mobject.dot(at: .zero)
        scene.add(dot)
        scene.play(
            .shift(dot, by: Vec2(1, 0), duration: 1, rate: .linear),
            .fadeOut(dot, duration: 1, rate: .linear)
        )

        // The zero-shift fade drives only opacity; the parallel shift keeps
        // ownership of the position.
        let mid = try #require(scene.snapshot(at: 0.5).first)
        #expect(approx(mid.position, Vec2(0.5, 0)))
        #expect(approx(mid.opacity, 0.5))
        let end = try #require(scene.snapshot(at: 1).first)
        #expect(approx(end.position, Vec2(1, 0)))
        #expect(end.opacity == 0)
    }

    @Test func fadeInAfterTransformKeepsTransformedOpacity() throws {
        var scene = ManimScene()
        let circle = Mobject.circle(radius: 1)
        scene.play(.create(circle, duration: 1))
        scene.play(.transform(circle, into: Mobject.square().withOpacity(0.5), duration: 1))
        scene.play(.fadeIn(circle, duration: 1))

        // fadeIn restores the object's current opacity, not the stale
        // authored value from before the morph.
        let end = try #require(scene.snapshot(at: 3).first)
        #expect(approx(end.opacity, 0.5))
    }

    @Test func fadeInIntroducesFromShiftedTransparentState() throws {
        var scene = ManimScene()
        let dot = Mobject.dot(at: Vec2(0, 0))
        scene.play(.fadeIn(dot, shift: Vec2(0, 1), duration: 1, rate: .linear))

        let start = try #require(scene.snapshot(at: 0).first)
        #expect(start.opacity == 0)
        #expect(approx(start.position, Vec2(0, -1)))

        let end = try #require(scene.snapshot(at: 1).first)
        #expect(end.opacity == 1)
        #expect(approx(end.position, Vec2(0, 0)))
    }

    @Test func fadeOutEndsInvisible() throws {
        var scene = ManimScene()
        let dot = Mobject.dot()
        scene.add(dot)
        scene.play(.fadeOut(dot, duration: 1))
        let end = try #require(scene.snapshot(at: 1).first)
        #expect(end.opacity == 0)
    }

    @Test func transformMorphsGeometryAndStyle() throws {
        var scene = ManimScene()
        let circle = Mobject.circle(radius: 1).stroke(.red).fill(.red, opacity: 0.5)
        scene.play(.create(circle, duration: 1))
        let square = Mobject.square(sideLength: 4, at: Vec2(2, 0))
            .stroke(.blue)
            .fill(.blue, opacity: 1)
        scene.play(.transform(circle, into: square, duration: 1))

        let end = try #require(scene.snapshot(at: 2).first)
        #expect(end.id == circle.id)
        let box = try #require(end.worldPath.boundingBox())
        #expect(approx(box.min, Vec2(0, -2), tolerance: 1e-6))
        #expect(approx(box.max, Vec2(4, 2), tolerance: 1e-6))
        #expect(approx(end.strokeColor.red, ManimColor.blue.red, tolerance: 1e-9))
        #expect(approx(end.fillColor.alpha, 1, tolerance: 1e-9))

        // Midway the shape is neither the circle nor the square.
        let mid = try #require(scene.snapshot(at: 1.5).first)
        let midBox = try #require(mid.worldPath.boundingBox())
        #expect(midBox.max.x > 1)
        #expect(midBox.max.x < 4)
    }

    @Test func animationsAfterTransformKeepTargetingSameObject() throws {
        var scene = ManimScene()
        let circle = Mobject.circle(radius: 1)
        scene.play(.create(circle, duration: 1))
        scene.play(.transform(circle, into: Mobject.square(), duration: 1))
        scene.play(.shift(circle, by: Vec2(3, 0), duration: 1))

        let end = try #require(scene.snapshot(at: 3).first)
        #expect(end.id == circle.id)
        #expect(approx(end.position, Vec2(3, 0)))
        #expect(scene.snapshot(at: 3).count == 1)
    }

    @Test func thereAndBackLeavesStateWhereItStarted() throws {
        var scene = ManimScene()
        let dot = Mobject.dot(at: .zero)
        scene.add(dot)
        scene.play(.shift(dot, by: Vec2(2, 0), duration: 1, rate: .thereAndBack))

        let mid = try #require(scene.snapshot(at: 0.5).first)
        #expect(approx(mid.position, Vec2(2, 0)))
        let end = try #require(scene.snapshot(at: 1).first)
        #expect(approx(end.position, Vec2(0, 0)))
        // Follow-up animations start from the returned-to state.
        #expect(approx(scene.state(of: dot)?.position ?? Vec2(9, 9), Vec2(0, 0)))
    }

    @Test func nonRevealingAnimationIntroducesAtItsPlayTime() throws {
        var scene = ManimScene()
        scene.wait(2)
        let dot = Mobject.dot(at: .zero)
        scene.play(.shift(dot, by: Vec2(1, 0), duration: 1, rate: .linear))

        // Hidden before the play call's point in the timeline...
        let before = try #require(scene.snapshot(at: 1).first { $0.id == dot.id })
        #expect(before.opacity == 0)
        // ...visible and animating from it.
        let atStart = try #require(scene.snapshot(at: 2).first { $0.id == dot.id })
        #expect(atStart.opacity == 1)
        #expect(approx(atStart.position, Vec2(0, 0)))
        let end = try #require(scene.snapshot(at: 3).first { $0.id == dot.id })
        #expect(approx(end.position, Vec2(1, 0)))
    }

    @Test func fadeInOnVisibleMobjectFadesInPlace() throws {
        var scene = ManimScene()
        let dot = Mobject.dot(at: Vec2(1, 1))
        scene.add(dot)
        scene.wait(1)
        scene.play(.fadeIn(dot, shift: Vec2(0, 1), duration: 1, rate: .linear))

        // Restarts from transparent, shifted back...
        let start = try #require(scene.snapshot(at: 1).first)
        #expect(start.opacity == 0)
        #expect(approx(start.position, Vec2(1, 0)))
        // ...and ends opaque at the position it already had.
        let end = try #require(scene.snapshot(at: 2).first)
        #expect(end.opacity == 1)
        #expect(approx(end.position, Vec2(1, 1)))
    }

    @Test func createOnVisibleMobjectRedrawsOutline() throws {
        var scene = ManimScene()
        let circle = Mobject.circle(radius: 1)
        scene.play(.create(circle, duration: 1))
        scene.wait(1)
        scene.play(.create(circle, duration: 2, rate: .linear))

        let midway = try #require(scene.snapshot(at: 3).first)
        #expect(approx(midway.strokeEnd, 0.5))
        let end = try #require(scene.snapshot(at: 4).first)
        #expect(end.strokeEnd == 1)
    }

    @Test func snapshotClampsOutOfRangeTimes() throws {
        var scene = ManimScene()
        let dot = Mobject.dot(at: .zero)
        scene.add(dot)
        scene.play(.shift(dot, by: Vec2(1, 0), duration: 1))

        let before = try #require(scene.snapshot(at: -5).first)
        #expect(approx(before.position, Vec2(0, 0)))
        let after = try #require(scene.snapshot(at: 100).first)
        #expect(approx(after.position, Vec2(1, 0)))
    }

    @Test func snapshotPreservesInsertionOrder() {
        var scene = ManimScene()
        let first = Mobject.circle(radius: 1)
        let second = Mobject.square()
        let third = Mobject.dot()
        scene.add(first, second)
        scene.play(.create(third, duration: 1))

        let ids = scene.snapshot(at: 1).map(\.id)
        #expect(ids == [first.id, second.id, third.id])
    }
}
