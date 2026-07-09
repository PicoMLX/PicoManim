import Testing
import Foundation
@testable import PicoManim

private func approx(_ a: Double, _ b: Double, tolerance: Double = 1e-9) -> Bool {
    abs(a - b) <= tolerance
}

private func approx(_ a: Vec2, _ b: Vec2, tolerance: Double = 1e-9) -> Bool {
    approx(a.x, b.x, tolerance: tolerance) && approx(a.y, b.y, tolerance: tolerance)
}

@Suite("Updaters")
struct UpdaterTests {
    @Test func updaterIsAPureFunctionOfTime() throws {
        var scene = ManimScene()
        let dot = Mobject.dot()
        scene.add(dot)
        scene.always(dot) { time, state in
            state.moved(to: Vec2(Foundation.cos(time), Foundation.sin(time)))
        }
        scene.wait(10)

        let quarter = try #require(scene.snapshot(at: .pi / 2).first)
        #expect(approx(quarter.position, Vec2(0, 1), tolerance: 1e-9))
        let half = try #require(scene.snapshot(at: .pi).first)
        #expect(approx(half.position, Vec2(-1, 0), tolerance: 1e-9))
        // Evaluating the same time twice gives the same state (pure).
        let again = try #require(scene.snapshot(at: .pi / 2).first)
        #expect(approx(again.position, quarter.position))
    }

    @Test func updaterLayersOnTopOfAnimations() throws {
        var scene = ManimScene()
        let dot = Mobject.dot(at: .zero)
        scene.add(dot)
        scene.always(dot) { time, state in
            state.shifted(by: Vec2(0, time))
        }
        scene.play(.shift(dot, by: Vec2(2, 0), duration: 1, rate: .linear))

        let mid = try #require(scene.snapshot(at: 0.5).first)
        // Animated x plus updater-driven y.
        #expect(approx(mid.position, Vec2(1, 0.5)))
        let end = try #require(scene.snapshot(at: 1).first)
        #expect(approx(end.position, Vec2(2, 1)))
    }

    @Test func updaterStartsAtRegistrationTime() throws {
        var scene = ManimScene()
        let dot = Mobject.dot(at: .zero)
        scene.add(dot)
        scene.wait(1)
        scene.always(dot) { _, state in
            state.shifted(by: Vec2(5, 0))
        }
        scene.wait(1)

        let before = try #require(scene.snapshot(at: 0.5).first)
        #expect(approx(before.position, Vec2(0, 0)))
        let after = try #require(scene.snapshot(at: 1.5).first)
        #expect(approx(after.position, Vec2(5, 0)))
    }

    @Test func duringWindowLimitsTheUpdater() throws {
        var scene = ManimScene()
        let dot = Mobject.dot(at: .zero)
        scene.add(dot)
        scene.always(dot, during: 1...2) { _, state in
            state.withOpacity(0.5)
        }
        scene.wait(3)

        #expect(try #require(scene.snapshot(at: 0.5).first).opacity == 1)
        #expect(try #require(scene.snapshot(at: 1.5).first).opacity == 0.5)
        // Outside the window the underlying animated state shows again.
        #expect(try #require(scene.snapshot(at: 2.5).first).opacity == 1)
    }

    @Test func updaterOnUnseenMobjectAddsIt() throws {
        var scene = ManimScene()
        scene.wait(1)
        let dot = Mobject.dot(at: Vec2(3, 3))
        scene.always(dot) { _, state in state }

        // Hidden before its introduction, visible afterwards.
        let before = try #require(scene.snapshot(at: 0.5).first)
        #expect(before.opacity == 0)
        let after = try #require(scene.snapshot(at: 1).first)
        #expect(after.opacity == 1)
        #expect(approx(after.position, Vec2(3, 3)))
    }

    @Test func updatersComposeInRegistrationOrder() throws {
        var scene = ManimScene()
        let dot = Mobject.dot(at: Vec2(1, 0))
        scene.add(dot)
        scene.always(dot) { _, state in
            state.shifted(by: Vec2(1, 0)) // 1 -> 2
        }
        scene.always(dot) { _, state in
            state.moved(to: state.position * 2) // 2 -> 4
        }
        scene.wait(1)

        let end = try #require(scene.snapshot(at: 1).first)
        #expect(approx(end.position, Vec2(4, 0)))
    }

    @Test func buildCursorIgnoresUpdaters() throws {
        var scene = ManimScene()
        let dot = Mobject.dot(at: .zero)
        scene.add(dot)
        scene.always(dot) { _, state in
            state.shifted(by: Vec2(100, 0))
        }
        // Later animations start from the un-updated cursor state.
        scene.play(.shift(dot, by: Vec2(1, 0), duration: 1, rate: .linear))
        #expect(approx(scene.state(of: dot)?.position ?? Vec2(-1, -1), Vec2(1, 0)))
    }
}
