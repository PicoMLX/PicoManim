/// A 2D affine transform decomposed into scale, rotation, and translation,
/// applied in that order: `p' = translation + rotate(scale * p)`.
///
/// Keeping the components separate (instead of a raw matrix) lets animations
/// interpolate rotation angles and scales independently without shearing.
public struct Transform2D: Sendable, Hashable {
    /// Translation applied last, in scene units.
    public var translation: Vec2
    /// Counterclockwise rotation in radians, applied after scaling.
    public var rotation: Double
    /// Per-axis scale, applied first.
    public var scale: Vec2

    public init(translation: Vec2 = .zero, rotation: Double = 0, scale: Vec2 = Vec2(1, 1)) {
        self.translation = translation
        self.rotation = rotation
        self.scale = scale
    }

    public static let identity = Transform2D()

    /// Applies the transform to a point.
    public func apply(to point: Vec2) -> Vec2 {
        (point * scale).rotated(by: rotation) + translation
    }

    /// Component-wise linear interpolation between two transforms.
    public static func lerp(_ a: Transform2D, _ b: Transform2D, _ t: Double) -> Transform2D {
        Transform2D(
            translation: Vec2.lerp(a.translation, b.translation, t),
            rotation: PicoManim.lerp(a.rotation, b.rotation, t),
            scale: Vec2.lerp(a.scale, b.scale, t)
        )
    }
}
