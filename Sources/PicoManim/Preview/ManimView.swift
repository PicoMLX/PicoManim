#if canImport(SwiftUI)
import Foundation
import SwiftUI

/// A SwiftUI player for a ``ManimScene``: renders the scene into a
/// `Canvas` and provides play/pause, restart, and scrubbing controls.
///
/// ```swift
/// import PicoManim
///
/// struct ContentView: View {
///     var body: some View {
///         ManimView(scene: .demo)
///     }
/// }
/// ```
///
/// Because scenes are evaluated purely by time, the view can loop and
/// scrub freely; playback state is just an anchor time plus a clock.
public struct ManimView: View {
    public var scene: ManimScene

    private let loops: Bool
    private let showsControls: Bool
    /// Visible scene area in scene units (width, height). The scene is
    /// scaled uniformly to fit this frame inside the view.
    private let frameSize: Vec2
    private let background: ManimColor

    @State private var isPlaying: Bool
    /// Playhead position when `anchorDate` was set.
    @State private var anchorTime: Double = 0
    /// Wall-clock moment playback (re)started; ignored while paused.
    @State private var anchorDate = Date()

    public init(
        scene: ManimScene,
        autoplays: Bool = true,
        loops: Bool = true,
        showsControls: Bool = true,
        frameSize: Vec2 = Vec2(14.0 + 2.0 / 9.0, 8.0),
        background: ManimColor = .background
    ) {
        self.scene = scene
        self.loops = loops
        self.showsControls = showsControls
        self.frameSize = frameSize
        self.background = background
        self._isPlaying = State(initialValue: autoplays && scene.duration > 0)
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !isPlaying)) { timeline in
            let time = playhead(at: timeline.date)
            VStack(spacing: 0) {
                canvas(time: time)
                if showsControls {
                    controls(time: time)
                }
            }
            .onChange(of: timeline.date) { _, newDate in
                if isPlaying && !loops && playhead(at: newDate) >= scene.duration {
                    anchorTime = scene.duration
                    isPlaying = false
                }
            }
        }
        .background(uiColor(background))
    }

    // MARK: - Playback

    private func playhead(at date: Date) -> Double {
        let total = scene.duration
        guard total > 0 else { return 0 }
        guard isPlaying else { return clamp(anchorTime, 0...total) }
        let raw = anchorTime + date.timeIntervalSince(anchorDate)
        if loops {
            return raw.truncatingRemainder(dividingBy: total)
        }
        return Swift.min(raw, total)
    }

    private func togglePlayback(from time: Double) {
        if isPlaying {
            anchorTime = time
            isPlaying = false
        } else {
            anchorTime = (!loops && time >= scene.duration) ? 0 : time
            anchorDate = Date()
            isPlaying = true
        }
    }

    private func seek(to time: Double) {
        anchorTime = clamp(time, 0...Swift.max(scene.duration, 0))
        anchorDate = Date()
    }

    // MARK: - Rendering

    private func canvas(time: Double) -> some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(uiColor(background))
            )
            guard size.width > 0, size.height > 0 else { return }

            let scale = Swift.min(Double(size.width) / frameSize.x, Double(size.height) / frameSize.y)
            let centerX = Double(size.width) / 2
            let centerY = Double(size.height) / 2
            func viewPoint(_ p: Vec2) -> CGPoint {
                CGPoint(x: centerX + p.x * scale, y: centerY - p.y * scale)
            }

            for mobject in scene.snapshot(at: time) {
                var path = Path()
                for subpath in mobject.worldPath.subpaths where !subpath.curves.isEmpty {
                    path.move(to: viewPoint(subpath.curves[0].p0))
                    for curve in subpath.curves {
                        path.addCurve(
                            to: viewPoint(curve.p1),
                            control1: viewPoint(curve.c1),
                            control2: viewPoint(curve.c2)
                        )
                    }
                    if subpath.isClosed {
                        path.closeSubpath()
                    }
                }

                let fillAlpha = mobject.effectiveFillAlpha
                if fillAlpha > 0.001 {
                    context.fill(path, with: .color(uiColor(mobject.fillColor, alpha: fillAlpha)))
                }

                let strokeAlpha = mobject.effectiveStrokeAlpha
                if strokeAlpha > 0.001, mobject.strokeWidth > 0, mobject.strokeEnd > mobject.strokeStart {
                    var strokePath = path
                    if mobject.strokeStart > 0 || mobject.strokeEnd < 1 {
                        strokePath = path.trimmedPath(
                            from: CGFloat(mobject.strokeStart),
                            to: CGFloat(mobject.strokeEnd)
                        )
                    }
                    context.stroke(
                        strokePath,
                        with: .color(uiColor(mobject.strokeColor, alpha: strokeAlpha)),
                        style: StrokeStyle(
                            // 100 Manim stroke units = 1 scene unit.
                            lineWidth: CGFloat(mobject.strokeWidth / 100 * scale),
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
            }
        }
        .accessibilityLabel("Animation preview")
    }

    // MARK: - Controls

    private func controls(time: Double) -> some View {
        HStack(spacing: 12) {
            Button {
                togglePlayback(from: time)
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            Button {
                seek(to: 0)
            } label: {
                Image(systemName: "gobackward")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Restart")

            Slider(
                value: Binding(
                    get: { time },
                    set: { seek(to: $0) }
                ),
                in: 0...Swift.max(scene.duration, 0.001)
            )
            .accessibilityLabel("Timeline")

            Text(timeLabel(time))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func timeLabel(_ time: Double) -> String {
        String(format: "%.1fs / %.1fs", time, scene.duration)
    }

    private func uiColor(_ color: ManimColor, alpha: Double? = nil) -> Color {
        Color(red: color.red, green: color.green, blue: color.blue, opacity: alpha ?? color.alpha)
    }
}

#Preview("Demo scene") {
    ManimView(scene: .demo)
        .frame(width: 640, height: 420)
}
#endif
