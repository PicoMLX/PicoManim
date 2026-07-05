/// An RGBA color with components in the 0...1 range.
///
/// Includes the classic Manim palette as static constants so scenes look
/// familiar out of the box (for example ``blue``, ``red``, ``yellow``).
public struct ManimColor: Sendable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Creates a color from a 24-bit `0xRRGGBB` value.
    public init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// A copy of this color with its alpha component replaced by `alpha`.
    public func withOpacity(_ alpha: Double) -> ManimColor {
        ManimColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Component-wise linear interpolation between two colors.
    public static func lerp(_ a: ManimColor, _ b: ManimColor, _ t: Double) -> ManimColor {
        ManimColor(
            red: a.red + (b.red - a.red) * t,
            green: a.green + (b.green - a.green) * t,
            blue: a.blue + (b.blue - a.blue) * t,
            alpha: a.alpha + (b.alpha - a.alpha) * t
        )
    }

    // MARK: - Manim palette

    public static let white = ManimColor(hex: 0xFFFFFF)
    public static let black = ManimColor(hex: 0x000000)
    public static let gray = ManimColor(hex: 0x888888)
    public static let lightGray = ManimColor(hex: 0xBBBBBB)
    public static let darkGray = ManimColor(hex: 0x444444)

    public static let blue = ManimColor(hex: 0x58C4DD)
    public static let teal = ManimColor(hex: 0x5CD0B3)
    public static let green = ManimColor(hex: 0x83C167)
    public static let yellow = ManimColor(hex: 0xFFFF00)
    public static let gold = ManimColor(hex: 0xF0AC5F)
    public static let red = ManimColor(hex: 0xFC6255)
    public static let maroon = ManimColor(hex: 0xC55F73)
    public static let purple = ManimColor(hex: 0x9A72AC)
    public static let pink = ManimColor(hex: 0xD147BD)
    public static let orange = ManimColor(hex: 0xFF862F)

    /// The default dark scene background.
    public static let background = ManimColor(hex: 0x111111)
}
