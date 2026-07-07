import Foundation

/// Evenly spaced tick values covering `range` at multiples of `spacing`,
/// clamped into the range so floating-point drift can't place a tick just
/// past an endpoint. Advances by integer tick index, so ranges at huge
/// offsets (where `value + spacing` would round back to `value`) terminate;
/// ranges whose tick indices can't be represented exactly, or that would
/// produce an absurd number of ticks, return no ticks at all.
private func tickValues(in range: ClosedRange<Double>, spacing: Double) -> [Double] {
    guard spacing > 0 else { return [] }
    let epsilon = spacing * 1e-9
    let firstIndex = ((range.lowerBound - epsilon) / spacing).rounded(.up)
    let lastIndex = ((range.upperBound + epsilon) / spacing).rounded(.down)
    // Beyond 2^53 the index math itself loses integers; and a range that
    // wants outlandishly many ticks is a degenerate ask. No ticks, no hang.
    let indexLimit = 9e15
    guard firstIndex <= lastIndex,
          abs(firstIndex) < indexLimit, abs(lastIndex) < indexLimit,
          lastIndex - firstIndex < 100_000 else { return [] }
    return (Int(firstIndex)...Int(lastIndex)).map { index in
        clamp(Double(index) * spacing, range)
    }
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
/// The axes cross at value (0, 0) when the ranges include zero; otherwise
/// each axis hugs the edge nearest the missing origin (the lower edge when
/// the range sits above zero, the upper edge when it sits below).
public struct Axes: Sendable {
    public let xRange: ClosedRange<Double>
    public let yRange: ClosedRange<Double>
    /// Scene-unit width and height of the plotting area.
    public let size: Vec2
    /// Scene position of the plotting area's center.
    public let center: Vec2
    /// The axis lines and ticks, ready to add or animate.
    public let mobjects: MobjectGroup

    // The value-to-scene mapping, precomputed once: scene = origin +
    // (value - lowerBound) * factor per axis. A degenerate (zero-span)
    // range maps every value to the middle of the area instead of
    // dividing by zero; genuinely tiny spans keep their exact factor.
    private let xOrigin: Double
    private let yOrigin: Double
    private let xFactor: Double
    private let yFactor: Double

    public init(
        x xRange: ClosedRange<Double>,
        y yRange: ClosedRange<Double>,
        size: Vec2 = Vec2(8, 5),
        at center: Vec2 = .zero,
        xTickSpacing: Double = 1,
        yTickSpacing: Double = 1,
        tickSize: Double = 0.1,
        color: ManimColor = .lightGray
    ) {
        self.xRange = xRange
        self.yRange = yRange
        self.size = size
        self.center = center

        let xSpan = xRange.upperBound - xRange.lowerBound
        let ySpan = yRange.upperBound - yRange.lowerBound
        let areaMin = center - size / 2
        let xFactor = xSpan > 0 ? size.x / xSpan : 0
        let yFactor = ySpan > 0 ? size.y / ySpan : 0
        let xOrigin = xSpan > 0 ? areaMin.x : center.x
        let yOrigin = ySpan > 0 ? areaMin.y : center.y
        self.xFactor = xFactor
        self.yFactor = yFactor
        self.xOrigin = xOrigin
        self.yOrigin = yOrigin
        func scenePoint(_ x: Double, _ y: Double) -> Vec2 {
            Vec2(
                xOrigin + (x - xRange.lowerBound) * xFactor,
                yOrigin + (y - yRange.lowerBound) * yFactor
            )
        }

        // Axis lines cross at value zero when available; otherwise they hug
        // the edge nearest the missing origin.
        let axisY = yRange.contains(0) ? 0 : (yRange.upperBound < 0 ? yRange.upperBound : yRange.lowerBound)
        let axisX = xRange.contains(0) ? 0 : (xRange.upperBound < 0 ? xRange.upperBound : xRange.lowerBound)
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
        for value in tickValues(in: xRange, spacing: xTickSpacing) {
            let anchor = scenePoint(value, axisY)
            mobjects.append(
                Mobject.line(
                    from: anchor - Vec2(0, tickSize / 2),
                    to: anchor + Vec2(0, tickSize / 2)
                ).stroke(color)
            )
        }
        for value in tickValues(in: yRange, spacing: yTickSpacing) {
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
        Vec2(
            xOrigin + (x - xRange.lowerBound) * xFactor,
            yOrigin + (y - yRange.lowerBound) * yFactor
        )
    }

    /// The graph of `function` sampled uniformly across `range` (the full
    /// x-range by default) as a polyline mobject in scene coordinates.
    /// Values outside the y-range are drawn where they land, not clipped.
    /// Non-finite samples (a pole, a domain error) split the graph into
    /// separate branches instead of poisoning the geometry; a graph with no
    /// drawable branch comes back with an empty path.
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
        // Consecutive finite samples form runs; each run becomes one open
        // subpath, so a sampled pole separates the branches around it.
        var runs: [[Vec2]] = [[]]
        for index in 0..<count {
            let x = domain.lowerBound + Double(index) * step
            let y = function(x)
            if y.isFinite {
                runs[runs.count - 1].append(point(x: x, y: y))
            } else if !(runs.last?.isEmpty ?? true) {
                runs.append([])
            }
        }
        let subpaths = runs.filter { $0.count >= 2 }.map { run in
            BezierPath.Subpath(
                curves: zip(run, run.dropFirst()).map { CubicCurve.line(from: $0, to: $1) },
                isClosed: false
            )
        }
        guard !subpaths.isEmpty else {
            return Mobject(path: BezierPath(subpaths: []), strokeColor: color)
                .stroke(color, width: strokeWidth)
        }
        let path = BezierPath(subpaths: subpaths)
        let localCenter = path.boundingBoxCenter
        var graph = Mobject(path: path.mapPoints { $0 - localCenter }, strokeColor: color)
        graph.position = localCenter
        return graph.stroke(color, width: strokeWidth)
    }
}
