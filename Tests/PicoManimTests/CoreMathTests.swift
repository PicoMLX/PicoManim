import Testing
@testable import PicoManim

private func approx(_ a: Double, _ b: Double, tolerance: Double = 1e-9) -> Bool {
    abs(a - b) <= tolerance
}

private func approx(_ a: Vec2, _ b: Vec2, tolerance: Double = 1e-9) -> Bool {
    approx(a.x, b.x, tolerance: tolerance) && approx(a.y, b.y, tolerance: tolerance)
}

@Suite("Vectors and transforms")
struct VectorTests {
    @Test func rotationQuarterTurn() {
        let rotated = Vec2(1, 0).rotated(by: .pi / 2)
        #expect(approx(rotated, Vec2(0, 1), tolerance: 1e-12))
    }

    @Test func lerpMidpoint() {
        #expect(approx(Vec2.lerp(Vec2(0, 0), Vec2(2, 4), 0.5), Vec2(1, 2)))
    }

    @Test func lengthOfUnitDirections() {
        for step in 0..<8 {
            let direction = Vec2.direction(Double(step) * .pi / 4)
            #expect(approx(direction.length, 1, tolerance: 1e-12))
        }
    }

    @Test func transformAppliesScaleRotationTranslationInOrder() {
        let transform = Transform2D(
            translation: Vec2(1, 1),
            rotation: .pi / 2,
            scale: Vec2(2, 2)
        )
        // (1, 0) -> scaled (2, 0) -> rotated (0, 2) -> translated (1, 3)
        #expect(approx(transform.apply(to: Vec2(1, 0)), Vec2(1, 3), tolerance: 1e-12))
    }

    @Test func identityTransformIsANoOp() {
        let point = Vec2(3.5, -2.25)
        #expect(approx(Transform2D.identity.apply(to: point), point))
    }

    @Test func transformLerpEndpoints() {
        let a = Transform2D.identity
        let b = Transform2D(translation: Vec2(2, 0), rotation: .pi, scale: Vec2(3, 3))
        let mid = Transform2D.lerp(a, b, 0.5)
        #expect(approx(mid.translation, Vec2(1, 0)))
        #expect(approx(mid.rotation, .pi / 2))
        #expect(approx(mid.scale, Vec2(2, 2)))
    }
}

@Suite("Colors")
struct ColorTests {
    @Test func hexRoundTrip() {
        let color = ManimColor(hex: 0x58C4DD)
        #expect(approx(color.red, Double(0x58) / 255))
        #expect(approx(color.green, Double(0xC4) / 255))
        #expect(approx(color.blue, Double(0xDD) / 255))
        #expect(color.alpha == 1)
    }

    @Test func withOpacityReplacesAlphaOnly() {
        let color = ManimColor.red.withOpacity(0.25)
        #expect(color.alpha == 0.25)
        #expect(color.red == ManimColor.red.red)
    }

    @Test func lerpEndpointsAndMidpoint() {
        let mid = ManimColor.lerp(.black, .white, 0.5)
        #expect(approx(mid.red, 0.5))
        #expect(approx(mid.green, 0.5))
        #expect(approx(mid.blue, 0.5))
        let end = ManimColor.lerp(.black, .white, 1)
        #expect(approx(end.red, 1))
    }
}
