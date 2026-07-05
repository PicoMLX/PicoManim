import Foundation

/// A 2D vector in scene units. PicoManim scenes use Manim's coordinate
/// convention: the origin at the center of the frame, +x to the right,
/// +y up, and a frame that is 8 units tall by default.
public typealias Vec2 = SIMD2<Double>

extension SIMD2 where Scalar == Double {
    /// The Euclidean length of the vector.
    public var length: Double {
        Foundation.hypot(x, y)
    }

    /// The vector rotated counterclockwise by `angle` radians around the origin.
    public func rotated(by angle: Double) -> SIMD2<Double> {
        let c = Foundation.cos(angle)
        let s = Foundation.sin(angle)
        return SIMD2(x * c - y * s, x * s + y * c)
    }

    /// Linear interpolation between `a` and `b` at parameter `t`.
    public static func lerp(_ a: SIMD2<Double>, _ b: SIMD2<Double>, _ t: Double) -> SIMD2<Double> {
        a + (b - a) * t
    }

    /// A unit vector at `angle` radians from the +x axis.
    public static func direction(_ angle: Double) -> SIMD2<Double> {
        SIMD2(Foundation.cos(angle), Foundation.sin(angle))
    }
}

/// Linear interpolation between two scalars.
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * t
}

/// Clamps `value` into `range`.
func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
    Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
}
