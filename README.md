<!-- Mode: Reference -->

# PicoManim

A Swift animation library inspired by [Manim](https://www.manim.community), the mathematical animation engine popularized by 3Blue1Brown — built for Apple platforms with a live SwiftUI preview.

**Platforms:** macOS 15+, iOS 18+
**Swift:** 6.2+
**Rendering:** SwiftUI `Canvas`

## Phase 1 Scope

- **Shapes** — circle, ellipse, arc, dot, line, polyline, rectangle, square, triangle, regular polygon, arbitrary polygon; all stored as cubic Bézier paths so any shape can morph into any other.
- **Animation** — `create`, `fadeIn`/`fadeOut`, `shift`/`move`, `rotate`, `scale`, and morphing `transform`, with Manim-style rate functions (`smooth`, `linear`, `easeIn`/`Out`/`InOut`, `thereAndBack`, custom).
- **ManimView** — a SwiftUI player with play/pause, restart, looping, and scrubbing.

## Add PicoManim to Your Project

**Swift Package Manager (local):**

```swift
// Package.swift
dependencies: [
    .package(path: "../PicoManim"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "PicoManim", package: "PicoManim"),
    ]),
]
```

**Xcode:** File > Add Package Dependencies > Add Local > select the `PicoManim` directory.

## Build a Scene

A `ManimScene` is built imperatively, exactly like a Manim `Scene.construct`: successive `play` calls run one after another, and animations passed to a single `play` call run in parallel.

```swift
import PicoManim

let scene = ManimScene { scene in
    let circle = Mobject.circle(radius: 1.2)
        .stroke(.blue)
        .fill(.blue, opacity: 0.5)

    scene.play(.create(circle))
    scene.play(.shift(circle, by: Vec2(-3, 0)))

    let square = Mobject.square(sideLength: 2, at: Vec2(-3, 0))
        .stroke(.red)
        .fill(.red, opacity: 0.5)
    scene.play(.transform(circle, into: square))

    scene.play(
        .rotate(circle, by: .pi / 2),
        .scale(circle, by: 1.3)
    )
    scene.wait(0.5)
    scene.play(.fadeOut(circle, shift: Vec2(0, 1)))
}
```

Scenes use Manim's coordinate system: the origin at the center, +y up, and a frame 8 units tall.

**Key semantics:**

- Mobjects are value types with a stable identity. Fluent modifiers (`.fill`, `.stroke`, `.shifted`, ...) return styled copies that keep the same identity, which is how the scene knows later animations target the same on-screen object — even after a `transform` morphs it into another shape.
- `snapshot(at:)` returns every mobject's visual state at any time, as a pure function. Playback can scrub, loop, or render offline without replaying the scene. Use `state(of:)` while building to read where an earlier animation left an object.
- Parallel animations on the same mobject compose per property (a simultaneous `rotate` and `scale` both apply); two parallel animations driving the same property do not blend — the later one wins.

## Preview with ManimView

```swift
import SwiftUI
import PicoManim

struct ContentView: View {
    var body: some View {
        ManimView(scene: .demo)   // or your own scene
    }
}
```

`ManimView(scene:autoplays:loops:showsControls:frameSize:background:)` renders into a SwiftUI `Canvas` and provides play/pause, restart, and a scrubber. It works in Xcode Previews:

```swift
#Preview {
    ManimView(scene: .demo)
        .frame(width: 640, height: 420)
}
```

**Verify it worked:** `ManimScene.demo.duration` is greater than 0, and `ManimView(scene: .demo)` shows a blue circle being drawn in, morphing into a red square, and fading out.

## Shape Reference

| Factory | Default style |
| --- | --- |
| `Mobject.circle(radius:at:)` | red outline |
| `Mobject.ellipse(width:height:at:)` | red outline |
| `Mobject.arc(radius:startAngle:endAngle:at:)` | white outline |
| `Mobject.dot(at:radius:)` | white fill, no outline |
| `Mobject.line(from:to:)` | white outline |
| `Mobject.rectangle(width:height:at:)` / `.square(sideLength:at:)` | white outline |
| `Mobject.triangle(radius:at:)` / `.regularPolygon(sides:radius:at:)` | blue outline |
| `Mobject.polygon(_:)` / `.polyline(_:)` | blue / white outline |

Defaults mirror Manim's traditional colors, and the full Manim palette is available on `ManimColor` (`.blue`, `.red`, `.green`, `.yellow`, `.purple`, ...).

## Roadmap

- **Phase 2:** text and LaTeX mobjects, mobject groups, axes and coordinate systems, updaters.
- **Phase 3:** video export, camera moves, 3D.

## Run the Tests

```bash
swift test
```

The core (geometry, paths, timeline) has no SwiftUI dependency and tests run on any platform with a Swift 6.2 toolchain; `ManimView` compiles only where SwiftUI is available.
