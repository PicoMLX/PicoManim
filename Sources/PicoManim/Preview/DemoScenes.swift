extension ManimScene {
    /// A short tour of Phase 1: create, shift, parallel rotate + scale,
    /// morphing transforms, and fades. Used by the `ManimView` preview.
    public static var demo: ManimScene {
        ManimScene { scene in
            let circle = Mobject.circle(radius: 1.2)
                .stroke(.blue)
                .fill(.blue, opacity: 0.5)

            scene.play(.create(circle, duration: 1.2))
            scene.wait(0.3)
            scene.play(.shift(circle, by: Vec2(-3, 0)))

            let square = Mobject.square(sideLength: 2, at: Vec2(-3, 0))
                .stroke(.red)
                .fill(.red, opacity: 0.5)
            scene.play(.transform(circle, into: square, duration: 1.2))
            scene.wait(0.2)

            let dot = Mobject.dot(at: Vec2(3, 1))
            let label = Mobject.triangle(radius: 0.8, at: Vec2(3, 1))
                .stroke(.green)
                .fill(.green, opacity: 0.4)
            scene.play(.fadeIn(dot, shift: Vec2(0, -0.5), duration: 0.6))
            scene.play(.create(label, duration: 0.8))

            scene.play(
                .rotate(circle, by: .pi / 2, duration: 1),
                .scale(circle, by: 1.3, duration: 1),
                .shift(label, by: Vec2(0, -2), duration: 1)
            )
            scene.wait(0.3)

            let hexagon = Mobject.regularPolygon(sides: 6, radius: 1.2, at: Vec2(0, 0))
                .stroke(.purple)
                .fill(.purple, opacity: 0.5)
            scene.play(
                .transform(circle, into: hexagon, duration: 1.2),
                .fadeOut(dot, duration: 0.6),
                .fadeOut(label, shift: Vec2(0, -1), duration: 0.8)
            )
            scene.wait(0.4)
            scene.play(.fadeOut(circle, shift: Vec2(0, 1), duration: 0.8))
        }
    }
}
