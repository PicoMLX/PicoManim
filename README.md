<!-- Mode: Reference -->

# PicoManim

A Swift animation library inspired by [Manim](https://www.manim.community), the mathematical animation engine popularized by 3Blue1Brown — built for Apple platforms with a live SwiftUI preview.

**Platforms:** macOS 15+, iOS 18+
**Swift:** 6.2+
**Rendering:** SwiftUI `Canvas`

> **Status:** Phase 1 is landing as a stack of focused PRs. This package currently
> contains the core math layer (`Vec2`, `Transform2D`, `ManimColor`); shapes, the
> animation timeline, and the `ManimView` preview follow in the next PRs.

## Phase 1 Scope

- **Shapes** — circle, ellipse, arc, dot, line, polyline, rectangle, square, triangle, regular polygon, arbitrary polygon; all stored as cubic Bézier paths so any shape can morph into any other.
- **Animation** — `create`, `fadeIn`/`fadeOut`, `shift`/`move`, `rotate`, `scale`, and morphing `transform`, with Manim-style rate functions.
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

## Roadmap

- **Phase 1 (in progress):** shapes, animation timeline, SwiftUI preview.
- **Phase 2:** text and LaTeX mobjects, mobject groups, axes and coordinate systems, updaters.
- **Phase 3:** video export, camera moves, 3D.

## Run the Tests

```bash
swift test
```

The core has no SwiftUI dependency and tests run on any platform with a Swift 6.2 toolchain (CI covers macOS and Linux); SwiftUI-only code is fenced behind `#if canImport(SwiftUI)`.
