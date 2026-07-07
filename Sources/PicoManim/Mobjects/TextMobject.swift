#if canImport(CoreText)
import CoreGraphics
import CoreText
import Foundation

// Text mobjects: glyph outlines extracted with CoreText and stored as
// ordinary Bézier subpaths, so text draws in with `create`, morphs with
// `transform`, and styles like any other mobject.
//
// Only available where CoreText exists (Apple platforms); the rest of the
// package stays platform-neutral.
extension Mobject {
    /// A filled text mobject laid out on a single line.
    ///
    /// Glyph outlines become subpaths of one path, in font space scaled so
    /// that **a font size of 48 spans one scene unit per em** (Manim's
    /// familiar proportions: default text is a bit under one unit tall).
    /// The path is recentered on its bounding box, so rotation and scaling
    /// happen about the text's visual center.
    ///
    /// - Parameters:
    ///   - string: The text to lay out (single line).
    ///   - fontName: A PostScript or family name; `nil` uses the system font.
    ///   - fontSize: Manim-style font size; 48 → one scene unit per em.
    ///   - center: Scene position of the text's center.
    ///   - color: Fill color (text has no stroke by default, like Manim).
    public static func text(
        _ string: String,
        fontName: String? = nil,
        fontSize: Double = 48,
        at center: Vec2 = .zero,
        color: ManimColor = .white
    ) -> Mobject {
        let path = BezierPath.text(string, fontName: fontName, fontSize: fontSize)
        let localCenter = path.boundingBoxCenter
        var mobject = Mobject(
            path: path.mapPoints { $0 - localCenter },
            strokeColor: color.withOpacity(0),
            strokeWidth: 0,
            fillColor: color
        )
        mobject.position = center
        return mobject
    }
}

extension BezierPath {
    /// The outlines of `string` laid out on one line, in scene units
    /// (`fontSize` 48 → one unit per em), starting at the origin baseline.
    public static func text(
        _ string: String,
        fontName: String? = nil,
        fontSize: Double = 48
    ) -> BezierPath {
        // Lay out in font points, then scale to scene units: 48 pt = 1 unit.
        let pointSize: CGFloat = 48
        let unitsPerPoint = (fontSize / Double(pointSize)) / Double(pointSize)
        let font: CTFont
        if let fontName {
            font = CTFontCreateWithName(fontName as CFString, pointSize, nil)
        } else {
            font = CTFontCreateUIFontForLanguage(.system, pointSize, nil) ??
                CTFontCreateWithName("Helvetica" as CFString, pointSize, nil)
        }

        let attributed = NSAttributedString(
            string: string,
            attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]
        )
        let line = CTLineCreateWithAttributedString(attributed)

        var subpaths: [Subpath] = []
        let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
        for run in runs {
            let glyphCount = CTRunGetGlyphCount(run)
            guard glyphCount > 0 else { continue }
            var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
            var positions = [CGPoint](repeating: .zero, count: glyphCount)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)

            let attributes = CTRunGetAttributes(run) as? [NSAttributedString.Key: Any]
            let fontKey = NSAttributedString.Key(kCTFontAttributeName as String)
            // `as? CTFont` is rejected by the compiler ("conditional downcast
            // to CoreFoundation type will always succeed"), so type-check via
            // CFGetTypeID before the unconditional cast.
            let runFont: CTFont
            if let value = attributes?[fontKey], CFGetTypeID(value as CFTypeRef) == CTFontGetTypeID() {
                runFont = value as! CTFont
            } else {
                runFont = font
            }

            for index in 0..<glyphCount {
                guard let glyphPath = CTFontCreatePathForGlyph(runFont, glyphs[index], nil) else {
                    continue // whitespace has no outline
                }
                let origin = Vec2(Double(positions[index].x), Double(positions[index].y))
                subpaths.append(contentsOf: BezierPath.subpaths(
                    from: glyphPath,
                    offset: origin,
                    scale: unitsPerPoint
                ))
            }
        }
        return BezierPath(subpaths: subpaths)
    }

    /// Converts a CGPath (font space, y-up) into cubic Bézier subpaths,
    /// translated by `offset` (font points) and uniformly scaled.
    static func subpaths(from cgPath: CGPath, offset: Vec2, scale: Double) -> [Subpath] {
        var result: [Subpath] = []
        var currentCurves: [CubicCurve] = []
        var subpathStart = Vec2.zero
        var currentPoint = Vec2.zero

        func convert(_ point: CGPoint) -> Vec2 {
            (Vec2(Double(point.x), Double(point.y)) + offset) * scale
        }

        func closeCurrent(markClosed: Bool) {
            if markClosed, !currentCurves.isEmpty, (currentPoint - subpathStart).length > 1e-12 {
                // Explicitly add the closing edge so the outline is complete.
                currentCurves.append(.line(from: currentPoint, to: subpathStart))
            }
            if !currentCurves.isEmpty {
                result.append(Subpath(curves: currentCurves, isClosed: markClosed))
            }
            currentCurves = []
        }

        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                closeCurrent(markClosed: false)
                subpathStart = convert(element.points[0])
                currentPoint = subpathStart
            case .addLineToPoint:
                let end = convert(element.points[0])
                currentCurves.append(.line(from: currentPoint, to: end))
                currentPoint = end
            case .addQuadCurveToPoint:
                // Elevate the quadratic to a cubic.
                let control = convert(element.points[0])
                let end = convert(element.points[1])
                currentCurves.append(CubicCurve(
                    p0: currentPoint,
                    c1: currentPoint + (control - currentPoint) * (2.0 / 3.0),
                    c2: end + (control - end) * (2.0 / 3.0),
                    p1: end
                ))
                currentPoint = end
            case .addCurveToPoint:
                let c1 = convert(element.points[0])
                let c2 = convert(element.points[1])
                let end = convert(element.points[2])
                currentCurves.append(CubicCurve(p0: currentPoint, c1: c1, c2: c2, p1: end))
                currentPoint = end
            case .closeSubpath:
                closeCurrent(markClosed: true)
                currentPoint = subpathStart
            @unknown default:
                break
            }
        }
        closeCurrent(markClosed: false)
        return result
    }
}
#endif
