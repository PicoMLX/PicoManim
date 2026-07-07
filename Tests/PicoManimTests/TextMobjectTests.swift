#if canImport(CoreText)
import Testing
@testable import PicoManim

private func approx(_ a: Double, _ b: Double, tolerance: Double = 1e-6) -> Bool {
    abs(a - b) <= tolerance
}

@Suite("Text mobjects")
struct TextMobjectTests {
    @Test func textProducesGlyphOutlines() throws {
        let text = Mobject.text("Hi")
        #expect(!text.path.isEmpty)
        // "H" is one outline; "i" is a stem plus a dot.
        #expect(text.path.subpaths.count >= 3)
        #expect(text.path.subpaths.allSatisfy { !$0.curves.isEmpty })
        let box = try #require(text.worldPath.boundingBox())
        #expect(box.max.x > box.min.x)
    }

    @Test func defaultSizeSpansAboutOneUnitPerEm() throws {
        let text = Mobject.text("Xg") // cap height + descender
        let box = try #require(text.worldPath.boundingBox())
        let height = box.max.y - box.min.y
        // Cap-to-descender extent of a 48-point em should land well within
        // a unit but be clearly visible.
        #expect(height > 0.3 && height < 1.3)
    }

    @Test func fontSizeScalesLinearly() throws {
        let small = try #require(Mobject.text("X", fontSize: 48).worldPath.boundingBox())
        let large = try #require(Mobject.text("X", fontSize: 96).worldPath.boundingBox())
        let ratio = (large.max.y - large.min.y) / (small.max.y - small.min.y)
        #expect(approx(ratio, 2, tolerance: 0.05))
    }

    @Test func textIsCenteredFilledAndStrokeless() {
        let text = Mobject.text("Center", at: Vec2(2, 1))
        let center = text.worldPath.boundingBoxCenter
        #expect(approx(center.x, 2, tolerance: 1e-6))
        #expect(approx(center.y, 1, tolerance: 1e-6))
        #expect(text.strokeWidth == 0)
        #expect(text.effectiveFillAlpha == 1)
        #expect(text.effectiveStrokeAlpha == 0)
    }

    @Test func whitespaceAdvancesWithoutOutlines() throws {
        let spaced = try #require(Mobject.text("a a").worldPath.boundingBox())
        let tight = try #require(Mobject.text("aa").worldPath.boundingBox())
        #expect((spaced.max.x - spaced.min.x) > (tight.max.x - tight.min.x))
    }

    @Test func textAlignsAndMorphsLikeAnyPath() {
        let text = Mobject.text("O")
        let circle = BezierPath.circle(radius: 1)
        let (a, b) = text.path.aligned(with: circle)
        #expect(a.subpaths.count == b.subpaths.count)
        let mid = BezierPath.interpolate(a, b, 0.5)
        #expect(!mid.isEmpty)
    }

    @Test func createShowsTemporaryOutlineForStrokelessText() throws {
        var scene = ManimScene()
        let text = Mobject.text("Hi")
        scene.play(.create(text, duration: 1, rate: .linear))
        // While the outline draws in, a borrowed fill-colored stroke keeps
        // the (stroke-less) text visible.
        let quarter = try #require(scene.snapshot(at: 0.25).first)
        #expect(quarter.effectiveStrokeAlpha > 0)
        #expect(quarter.strokeWidth > 0)
        // The temporary outline is fully gone at the end.
        let end = try #require(scene.snapshot(at: 1).first)
        #expect(end.strokeWidth == 0)
        #expect(end.effectiveStrokeAlpha == 0)
        #expect(end.effectiveFillAlpha == 1)
    }

    @Test func textDrawsInWithCreate() throws {
        var scene = ManimScene()
        let text = Mobject.text("Hi")
        scene.play(.create(text, duration: 1, rate: .linear))
        let mid = try #require(scene.snapshot(at: 0.5).first)
        #expect(approx(mid.strokeEnd, 0.5, tolerance: 1e-9))
        let end = try #require(scene.snapshot(at: 1).first)
        #expect(end.fillOpacityFactor == 1)
    }
}
#endif
