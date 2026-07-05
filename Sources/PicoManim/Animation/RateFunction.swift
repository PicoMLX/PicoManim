/// Easing curves that map raw animation progress (0...1) to eased progress,
/// mirroring Manim's rate functions.
public enum RateFunction: Sendable {
    /// Constant speed.
    case linear
    /// Manim's default smooth ease (quintic smoothstep).
    case smooth
    /// Cubic ease-in: starts slow, ends fast.
    case easeIn
    /// Cubic ease-out: starts fast, ends slow.
    case easeOut
    /// Cubic ease-in-out.
    case easeInOut
    /// Runs to completion and back: returns to 0 at the end.
    case thereAndBack
    /// A custom easing function. It should map 0 to 0; whatever it maps
    /// 1 to becomes the animation's final progress.
    case custom(@Sendable (Double) -> Double)

    /// Applies the easing curve to `t`, clamping the input to 0...1.
    public func apply(_ t: Double) -> Double {
        let t = clamp(t, 0...1)
        switch self {
        case .linear:
            return t
        case .smooth:
            // 6t^5 - 15t^4 + 10t^3
            return t * t * t * (t * (6 * t - 15) + 10)
        case .easeIn:
            return t * t * t
        case .easeOut:
            let u = 1 - t
            return 1 - u * u * u
        case .easeInOut:
            if t < 0.5 {
                return 4 * t * t * t
            } else {
                let u = -2 * t + 2
                return 1 - u * u * u / 2
            }
        case .thereAndBack:
            let s = t < 0.5 ? 2 * t : 2 * (1 - t)
            return RateFunction.smooth.apply(s)
        case .custom(let function):
            return function(t)
        }
    }
}
