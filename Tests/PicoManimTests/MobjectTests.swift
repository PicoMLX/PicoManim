import Testing
@testable import PicoManim

private func approx(_ a: Double, _ b: Double, tolerance: Double = 1e-9) -> Bool {
    abs(a - b) <= tolerance
}

private func approx(_ a: Vec2, _ b: Vec2, tolerance: Double = 1e-9) -> Bool {
    approx(a.x, b.x, tolerance: tolerance) && approx(a.y, b.y, tolerance: tolerance)
}

@Suite("Mobjects")
struct MobjectTests {
    @Test func modifiersPreserveIdentity() {
        let circle = Mobject.circle(radius: 1)
        let styled = circle.fill(.blue, opacity: 0.5).stroke(.blue).shifted(by: Vec2(1, 0))
        #expect(styled.id == circle.id)
        #expect(styled.fillColor.alpha == 0.5)
        #expect(approx(styled.position, Vec2(1, 0)))
    }

    @Test func distinctMobjectsGetDistinctIdentity() {
        #expect(Mobject.circle(radius: 1).id != Mobject.circle(radius: 1).id)
    }

    @Test func lineIsCenteredOnMidpoint() throws {
        let line = Mobject.line(from: Vec2(0, 0), to: Vec2(2, 2))
        #expect(approx(line.position, Vec2(1, 1)))
        let box = try #require(line.worldPath.boundingBox())
        #expect(approx(box.min, Vec2(0, 0), tolerance: 1e-9))
        #expect(approx(box.max, Vec2(2, 2), tolerance: 1e-9))
    }

    @Test func polygonKeepsAuthoredWorldGeometry() throws {
        let points = [Vec2(1, 1), Vec2(3, 1), Vec2(3, 2), Vec2(1, 2)]
        let polygon = Mobject.polygon(points)
        let box = try #require(polygon.worldPath.boundingBox())
        #expect(approx(box.min, Vec2(1, 1), tolerance: 1e-9))
        #expect(approx(box.max, Vec2(3, 2), tolerance: 1e-9))
        // Local path is recentered so rotation/scaling happen about the center.
        #expect(approx(polygon.position, Vec2(2, 1.5)))
    }

    @Test func arcIsPositionedOnItsOwnCenterNotTheCircleCenter() throws {
        let arc = Mobject.arc(radius: 2, startAngle: 0, endAngle: .pi, at: Vec2(1, 0))
        let box = try #require(arc.worldPath.boundingBox())
        // Half circle around (1, 0): x spans -1...3, y spans 0...2.
        #expect(approx(box.min, Vec2(-1, 0), tolerance: 0.01))
        #expect(approx(box.max, Vec2(3, 2), tolerance: 0.01))
    }

    @Test func rotationHappensAboutOwnCenter() throws {
        let square = Mobject.square(sideLength: 2, at: Vec2(5, 0)).rotated(by: .pi / 4)
        let box = try #require(square.worldPath.boundingBox())
        let center = (box.min + box.max) / 2
        #expect(approx(center, Vec2(5, 0), tolerance: 1e-6))
        // Rotated square's bounding box is sqrt(2) wider.
        #expect(approx(box.max.x - box.min.x, 2 * 2.0.squareRoot(), tolerance: 1e-6))
    }

    @Test func scalingHappensAboutOwnCenter() throws {
        let square = Mobject.square(sideLength: 2, at: Vec2(-3, 1)).scaled(by: 2)
        let box = try #require(square.worldPath.boundingBox())
        #expect(approx(box.min, Vec2(-5, -1), tolerance: 1e-9))
        #expect(approx(box.max, Vec2(-1, 3), tolerance: 1e-9))
    }

    @Test func dotIsFilledWithoutStroke() {
        let dot = Mobject.dot()
        #expect(dot.strokeWidth == 0)
        #expect(dot.fillColor.alpha == 1)
        #expect(dot.effectiveFillAlpha == 1)
    }

    @Test func defaultStylesMirrorManim() {
        #expect(Mobject.circle(radius: 1).strokeColor == ManimColor.red)
        #expect(Mobject.square().strokeColor == ManimColor.white)
        #expect(Mobject.rectangle(width: 2, height: 1).strokeColor == ManimColor.white)
        #expect(Mobject.regularPolygon(sides: 5).strokeColor == ManimColor.blue)
        #expect(Mobject.line(from: .zero, to: Vec2(1, 0)).strokeColor == ManimColor.white)
        // Shapes default to no visible fill.
        #expect(Mobject.circle(radius: 1).effectiveFillAlpha == 0)
    }

    @Test func opacityFactorsMultiply() {
        let square = Mobject.square()
            .fill(.blue, opacity: 0.5)
            .withOpacity(0.5)
        #expect(approx(square.effectiveFillAlpha, 0.25))
        #expect(approx(square.effectiveStrokeAlpha, 0.5))
    }

    @Test func outOfRangeStyleInputsAreClamped() {
        let square = Mobject.square().stroke(.blue, width: -3).withOpacity(5)
        #expect(square.strokeWidth == 0)
        #expect(square.effectiveStrokeAlpha == 1)
        let negative = Mobject.square().withOpacity(-1)
        #expect(negative.effectiveStrokeAlpha == 0)
    }

    @Test func triangleIsRegularPolygonWithThreeSides() {
        let triangle = Mobject.triangle(radius: 1)
        #expect(triangle.path.curveCount == 3)
        #expect(triangle.path.subpaths[0].isClosed)
    }
}
