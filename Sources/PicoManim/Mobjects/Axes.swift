import Foundation

/// Evenly spaced tick values covering `range` at multiples of `spacing`.
private func tickValues(in range: ClosedRange<Double>, spacing: Double) -> [Double] {
    guard spacing > 0 else { return [] }
    let epsilon = spacing * 1e-9
    var value = (range.lowerBound / spacing - 1e-9).rounded(.up) * spacing
    var values: [Double] = []
    while value <= range.upperBound + epsilon {
        values.append(value)
        value += spacing
    }
    return values
}

extension MobjectGroup {
    /// A horizontal number line: a base line with evenly spaced ticks.
    ///
    /// - Parameters:
    ///   - range: The values the line spans.
    ///   - center: Scene position of the line's midpoint.
    ///   - length: Scene-unit length of the line.
    ///   - tickSpacing: Value distance between ticks.
    ///   - tickSize: Scene-unit height of each tick mark.
    public static func numberLine(
        range: ClosedRange<Double>,
        at center: Vec2 = .zero,
        length: Double = 8,
        tickSpacing: Double = 1,
        tickSize: Double = 0.1,
        color: ManimColor = .white
    ) -> MobjectGroup {
        let span = range.upperBound - range.lowerBound
        guard span > 0, length > 0 else { return MobjectGroup([]) }
        let start = center - Vec2(length / 2, 0)
        func scenePoint(_ value: Double) -> Vec2 {
            start + Vec2((value - range.lowerBound) / span * length, 0)
        }
        var mobjects = [
            Mobject.line(from: scenePoint(range.lowerBound), to: scenePoint(range.upperBound))
                .stroke(color)
        ]
        for value in tickValues(in: range, spacing: tickSpacing) {
            let anchor = scenePoint(value)
            mobjects.append(
                Mobject.line(
                    from: anchor - Vec2(0, tickSize / 2),
                    to: anchor + Vec2(0, tickSize / 2)
                ).stroke(color)
            )
        }
        return MobjectGroup(mobjects)
    }
}

/// A 2D coordinate system: two axis lines with ticks, a value-to-scene
/// mapping, and function plotting.
///
/// ```swift
/// let axes = Axes(x: -3...3, y: -1...9, size: Vec2(8, 5))
/// scene.play(.create(axes.mobjects, lag: 0.02))
/// scene.play(.create(axes.plot { $0 * $0 }))
/// ```
///
/// The axes cross at value (0, 0) when the ranges include zero, and hug
/// the lower edges otherwise (like Manim).
public struct Axes: Sendable {
    public let xRange: ClosedRange<Double>
    public let yRange: ClosedRange<Double>
    /// Scene-unit width and height of the plotting area.
    public let size: Vec2
    /// Scene position of the plotting area's center.
    public let center: Vec2
    /// The axis lines and ticks, ready to add or animate.
    public let mobjects: MobjectGroup

    public init(
        x xRange: ClosedRange<Double>,
        y yRange: ClosedRange<Double>,
        size: Vec2 = Vec2(8, 5),
        at center: Vec2 = .zero,
        tickSpacing: Double = 1,
        tickSize: Double = 0.1,
        color: ManimColor = .lightGray
    ) {
        self.xRange = xRange
        self.yRange = yRange
        self.size = size
        self.center = center

        let xSpan = Swift.max(xRange.upperBound - xRange.lowerBound, 1e-12)
        let ySpan = Swift.max(yRange.upperBound - yRange.lowerBound, 1e-12)
        let areaMin = center - size / 2
        func scenePoint(_ x: Double, _ y: Double) -> Vec2 {
            Vec2(
                areaMin.x + (x - xRange.lowerBound) / xSpan * size.x,
                areaMin.y + (y - yRange.lowerBound) / ySpan * size.y
            )
        }

        // Axis lines cross at value zero when available, else at the edges.
        let axisY = yRange.contains(0) ? 0 : yRange.lowerBound
        let axisX = xRange.contains(0) ? 0 : xRange.lowerBound
        var mobjects = [
            Mobject.line(
                from: scenePoint(xRange.lowerBound, axisY),
                to: scenePoint(xRange.upperBound, axisY)
            ).stroke(color),
            Mobject.line(
                from: scenePoint(axisX, yRange.lowerBound),
                to: scenePoint(axisX, yRange.upperBound)
            ).stroke(color)
        ]
        for value in tickValues(in: xRange, spacing: tickSpacing) {
            let anchor = scenePoint(value, axisY)
            mobjects.append(
                Mobject.line(
                    from: anchor - Vec2(0, tickSize / 2),
                    to: anchor + Vec2(0, tickSize / 2)
                ).stroke(color)
            )
        }
        for value in tickValues(in: yRange, spacing: tickSpacing) {
            let anchor = scenePoint(axisX, value)
            mobjects.append(
                Mobject.line(
                    from: anchor - Vec2(tickSize / 2, 0),
                    to: anchor + Vec2(tickSize / 2, 0)
                ).stroke(color)
            )
        }
        self.mobjects = MobjectGroup(mobjects)
    }

    /// The scene position of the value coordinate `(x, y)`.
    public func point(x: Double, y: Double) -> Vec2 {
        let xSpan = Swift.max(xRange.upperBound - xRange.lowerBound, 1e-12)
        let ySpan = Swift.max(yRange.upperBound - yRange.lowerBound, 1e-12)
        let areaMin = center - size / 2
        return Vec2(
            areaMin.x + (x - xRange.lowerBound) / xSpan * size.x,
            areaMin.y + (y - yRange.lowerBound) / ySpan * size.y
        )
    }

    /// The graph of `function` sampled uniformly across `range` (the full
    /// x-range by default) as a polyline mobject in scene coordinates.
    /// Values outside the y-range are drawn where they land, not clipped.
    public func plot(
        _ function: (Double) -> Double,
        in range: ClosedRange<Double>? = nil,
        samples: Int = 100,
        color: ManimColor = .yellow,
        strokeWidth: Double = 4
    ) -> Mobject {
        let domain = range ?? xRange
        let count = Swift.max(samples, 2)
        let step = (domain.upperBound - domain.lowerBound) / Double(count - 1)
        let points = (0..<count).map { index -> Vec2 in
            let x = domain.lowerBound + Double(index) * step
            return point(x: x, y: function(x))
        }
        return Mobject.polyline(points).stroke(color, width: strokeWidth)
    }
}
