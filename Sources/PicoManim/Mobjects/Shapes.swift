import Foundation

// Shape factories mirroring Manim's standard mobjects, including their
// traditional default colors (red circles, blue polygons, white lines).
//
// Every factory builds its path centered on the local origin and places the
// shape with the mobject's transform, so rotation and scaling always happen
// about the shape's own center.
extension Mobject {
    /// A circle. Defaults to Manim's red outline.
    public static func circle(radius: Double = 1, at center: Vec2 = .zero) -> Mobject {
        var mobject = Mobject(path: .circle(radius: radius), strokeColor: .red)
        mobject.position = center
        return mobject
    }

    /// An axis-aligned ellipse.
    public static func ellipse(width: Double, height: Double, at center: Vec2 = .zero) -> Mobject {
        var mobject = Mobject(path: .ellipse(width: width, height: height), strokeColor: .red)
        mobject.position = center
        return mobject
    }

    /// A circular arc from `startAngle` to `endAngle` (radians,
    /// counterclockwise) around `center`.
    public static func arc(
        radius: Double = 1,
        startAngle: Double = 0,
        endAngle: Double = Double.pi / 2,
        at center: Vec2 = .zero
    ) -> Mobject {
        let path = BezierPath.arc(radius: radius, startAngle: startAngle, endAngle: endAngle)
        let localCenter = path.boundingBoxCenter
        var mobject = Mobject(
            path: path.mapPoints { $0 - localCenter },
            strokeColor: .white
        )
        mobject.position = center + localCenter
        return mobject
    }

    /// A small filled dot.
    public static func dot(at center: Vec2 = .zero, radius: Double = 0.08) -> Mobject {
        var mobject = Mobject(
            path: .circle(radius: radius),
            strokeColor: ManimColor.white.withOpacity(0),
            strokeWidth: 0,
            fillColor: .white
        )
        mobject.position = center
        return mobject
    }

    /// A straight line segment.
    public static func line(from start: Vec2, to end: Vec2) -> Mobject {
        let midpoint = (start + end) / 2
        var mobject = Mobject(
            path: .line(from: start - midpoint, to: end - midpoint),
            strokeColor: .white
        )
        mobject.position = midpoint
        return mobject
    }

    /// An axis-aligned rectangle. Defaults to Manim's white outline
    /// (in Manim only the polygon-class shapes default to blue).
    public static func rectangle(width: Double, height: Double, at center: Vec2 = .zero) -> Mobject {
        var mobject = Mobject(path: .rectangle(width: width, height: height), strokeColor: .white)
        mobject.position = center
        return mobject
    }

    /// A square. Defaults to Manim's white outline.
    public static func square(sideLength: Double = 2, at center: Vec2 = .zero) -> Mobject {
        rectangle(width: sideLength, height: sideLength, at: center)
    }

    /// A regular polygon with `sides` vertices inscribed in a circle of
    /// `radius`, first vertex pointing up.
    public static func regularPolygon(
        sides: Int,
        radius: Double = 1,
        at center: Vec2 = .zero
    ) -> Mobject {
        precondition(sides >= 3, "A regular polygon needs at least 3 sides")
        var mobject = Mobject(
            path: .regularPolygon(sides: sides, radius: radius),
            strokeColor: .blue
        )
        mobject.position = center
        return mobject
    }

    /// An equilateral triangle inscribed in a circle of `radius`, pointing up.
    public static func triangle(radius: Double = 1, at center: Vec2 = .zero) -> Mobject {
        regularPolygon(sides: 3, radius: radius, at: center)
    }

    /// A closed polygon through the given scene-space points.
    public static func polygon(_ points: [Vec2]) -> Mobject {
        precondition(points.count >= 3, "A polygon needs at least 3 points")
        let path = BezierPath.polygon(points)
        let localCenter = path.boundingBoxCenter
        var mobject = Mobject(
            path: path.mapPoints { $0 - localCenter },
            strokeColor: .blue
        )
        mobject.position = localCenter
        return mobject
    }

    /// An open polyline through the given scene-space points.
    public static func polyline(_ points: [Vec2]) -> Mobject {
        precondition(points.count >= 2, "A polyline needs at least 2 points")
        let path = BezierPath.polyline(points)
        let localCenter = path.boundingBoxCenter
        var mobject = Mobject(
            path: path.mapPoints { $0 - localCenter },
            strokeColor: .white
        )
        mobject.position = localCenter
        return mobject
    }
}
