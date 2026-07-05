import Foundation

/// An animation timeline built imperatively, Manim-style, and evaluated
/// purely: build the scene once with `add`, `play`, and `wait`, then ask
/// for the visual state at any moment with ``snapshot(at:)``.
///
/// ```swift
/// let scene = ManimScene { scene in
///     let circle = Mobject.circle(radius: 1).fill(.blue, opacity: 0.5)
///     scene.play(.create(circle))
///     scene.play(.shift(circle, by: Vec2(2, 0)))
///     scene.play(.transform(circle, into: Mobject.square()))
/// }
/// ```
///
/// Because `snapshot(at:)` is a pure function of time, playback can be
/// scrubbed, looped, or rendered offline without replaying the scene.
///
/// Semantics, mirroring Manim:
/// - Successive `play` calls run sequentially.
/// - Animations passed to a single `play` call run in parallel. Parallel
///   animations on the *same* mobject compose per property (for example a
///   simultaneous shift and rotate), but two parallel animations driving
///   the same property will not blend — the later one wins.
/// - A mobject animated before ever being added is introduced by the
///   animation itself (`create` and `fadeIn` reveal it; other kinds show
///   it immediately, as `add` would).
public struct ManimScene: Sendable {
    /// One scheduled animation on the timeline, with its interpolation
    /// poles resolved at build time.
    struct Entry: Sendable {
        var startTime: Double
        var duration: Double
        var rate: RateFunction
        var kind: ManimAnimation.Kind
        var targetID: Mobject.ID
        /// The target's state when the animation begins.
        var startState: Mobject
        /// The target's state at full (uneased) progress.
        var endState: Mobject
        /// For `transform`: start and target paths restructured to match,
        /// precomputed so scrubbing stays cheap.
        var alignedPaths: (BezierPath, BezierPath)?
    }

    private var entries: [Entry] = []
    /// Each mobject's state at time zero (hidden until introduced).
    private var initialStates: [Mobject.ID: Mobject] = [:]
    /// Build cursor: each mobject's state after everything scheduled so far.
    private var currentStates: [Mobject.ID: Mobject] = [:]
    /// Draw order (insertion order).
    private var order: [Mobject.ID] = []

    /// Total length of the timeline in seconds.
    public private(set) var duration: Double = 0

    public init() {}

    /// Builds a scene in one expression.
    public init(_ build: (inout ManimScene) throws -> Void) rethrows {
        self.init()
        try build(&self)
    }

    // MARK: - Building

    /// Shows mobjects instantly at the current point in the timeline.
    /// Re-adding an already tracked mobject applies the passed state
    /// (position, style, geometry) instantly.
    public mutating func add(_ mobjects: Mobject...) {
        add(mobjects)
    }

    /// Shows mobjects instantly at the current point in the timeline.
    /// Re-adding an already tracked mobject applies the passed state
    /// (position, style, geometry) instantly.
    public mutating func add(_ mobjects: [Mobject]) {
        play(mobjects.map { mobject in
            // A zero-duration fadeIn only drives opacity, so re-adding a
            // tracked mobject routes through an instant morph instead —
            // otherwise the passed state would be silently dropped.
            if currentStates[mobject.id] != nil {
                return .transform(mobject, into: mobject, duration: 0, rate: .linear)
            }
            return .fadeIn(mobject, duration: 0, rate: .linear)
        })
    }

    /// Plays animations in parallel, then advances the timeline by the
    /// longest of their durations.
    public mutating func play(_ animations: ManimAnimation...) {
        play(animations)
    }

    /// Plays animations in parallel, then advances the timeline by the
    /// longest of their durations.
    public mutating func play(_ animations: [ManimAnimation]) {
        guard !animations.isEmpty else { return }
        let groupStart = duration
        var groupDuration: Double = 0
        // All animations in one play call are simultaneous, so every one of
        // them resolves its start pole from the state *before* the group —
        // never from a sibling's end state, which would make the mobject
        // jump at the start of the group.
        var groupStartStates = currentStates

        for animation in animations {
            let id = animation.mobject.id
            let startState: Mobject
            // The state the mobject is in as this group begins; the authored
            // value for a mobject this play call introduces.
            let preGroup = groupStartStates[id] ?? animation.mobject
            if groupStartStates[id] != nil {
                // Re-introducing animations (create, fadeIn) restart from a
                // hidden version of wherever the mobject currently is.
                startState = Self.introducedStartState(for: animation.kind, from: preGroup)
            } else {
                // First appearance: seed time zero with a hidden state so the
                // mobject doesn't exist on screen before this point.
                let hidden = Self.initialState(for: animation)
                initialStates[id] = hidden
                order.append(id)
                // A sibling animation in this same group starts from the
                // authored state, not from this animation's end.
                groupStartStates[id] = animation.mobject
                switch animation.kind {
                case .create, .fadeIn:
                    startState = hidden
                default:
                    // Non-revealing animation on a brand-new mobject: show it
                    // instantly (like `add`) and animate from there.
                    let visible = animation.mobject
                    entries.append(Entry(
                        startTime: groupStart,
                        duration: 0,
                        rate: .linear,
                        kind: .fadeIn(shift: .zero),
                        targetID: id,
                        startState: hidden,
                        endState: visible,
                        alignedPaths: nil
                    ))
                    startState = visible
                }
            }

            var entry = Entry(
                startTime: groupStart,
                duration: max(0, animation.duration),
                rate: animation.rate,
                kind: animation.kind,
                targetID: id,
                startState: startState,
                endState: startState,
                alignedPaths: nil
            )
            if case .transform(let target) = animation.kind {
                entry.alignedPaths = startState.path.aligned(with: target.path)
            }
            entry.endState = Self.endState(for: animation, from: startState, preGroup: preGroup)
            entries.append(entry)

            // Advance the build cursor to the state the animation actually
            // leaves behind (for rate functions like `thereAndBack` this is
            // not the end pole). Applied on top of the accumulated state so
            // sibling animations in this group all contribute.
            currentStates[id] = Self.apply(
                entry,
                easedProgress: entry.rate.apply(1),
                to: currentStates[id] ?? startState
            )
            groupDuration = max(groupDuration, entry.duration)
        }
        duration = groupStart + groupDuration
    }

    /// Advances the timeline by `seconds` with nothing moving.
    public mutating func wait(_ seconds: Double = 1) {
        duration += max(0, seconds)
    }

    /// The state a mobject will be in after everything scheduled so far.
    /// Useful when building follow-up animations relative to where an
    /// earlier animation left the object.
    public func state(of mobject: Mobject) -> Mobject? {
        currentStates[mobject.id]
    }

    // MARK: - Evaluation

    /// The visual state of every mobject at `time`, in draw order.
    /// Time is clamped to the scene's duration.
    public func snapshot(at time: Double) -> [Mobject] {
        let t = duration > 0 ? clamp(time, 0...duration) : 0
        var states = initialStates
        for entry in entries where entry.startTime <= t {
            let raw = entry.duration <= 0
                ? 1.0
                : Swift.min(1, (t - entry.startTime) / entry.duration)
            let eased = entry.rate.apply(raw)
            if let current = states[entry.targetID] {
                states[entry.targetID] = Self.apply(entry, easedProgress: eased, to: current)
            }
        }
        return order.compactMap { states[$0] }
    }

    // MARK: - Animation semantics

    /// The state a not-yet-seen mobject should have at time zero so it is
    /// invisible until its first animation runs.
    private static func initialState(for animation: ManimAnimation) -> Mobject {
        switch animation.kind {
        case .create, .fadeIn:
            return introducedStartState(for: animation.kind, from: animation.mobject)
        default:
            // Hidden until the instant reveal entry at the play time fires.
            var state = animation.mobject
            state.opacity = 0
            return state
        }
    }

    /// The start pole for a revealing animation: `state` made invisible in
    /// the way the animation expects to undo (outline retracted for
    /// `create`; transparent and shifted back for `fadeIn`).
    private static func introducedStartState(for kind: ManimAnimation.Kind, from state: Mobject) -> Mobject {
        var start = state
        switch kind {
        case .create:
            start.strokeStart = 0
            start.strokeEnd = 0
            start.fillOpacityFactor = 0
        case .fadeIn(let shift):
            start.opacity = 0
            start.transform.translation -= shift
        default:
            break
        }
        return start
    }

    /// The animation's end pole (state at uneased progress 1). `preGroup`
    /// is the mobject's state as the play group begins (the authored value
    /// on first introduction).
    private static func endState(
        for animation: ManimAnimation,
        from start: Mobject,
        preGroup: Mobject
    ) -> Mobject {
        var end = start
        switch animation.kind {
        case .create:
            end.strokeStart = 0
            end.strokeEnd = 1
            end.fillOpacityFactor = 1
            // Like fadeIn, create is a revealing animation: if the object was
            // fully transparent (e.g. after a fadeOut), restore its opacity
            // as the outline redraws.
            end.opacity = preGroup.opacity > 0 ? preGroup.opacity : animation.mobject.opacity
        case .fadeIn(let shift):
            // Fade back to the opacity the object currently has (it may have
            // changed via a transform). If it is currently fully transparent
            // (e.g. after a fadeOut), fall back to the authored opacity so
            // fadeIn always reveals something.
            end.opacity = preGroup.opacity > 0 ? preGroup.opacity : animation.mobject.opacity
            end.transform.translation += shift
        case .fadeOut(let shift):
            end.opacity = 0
            end.transform.translation += shift
        case .shift(let delta):
            end.transform.translation += delta
        case .move(let point):
            end.transform.translation = point
        case .rotate(let angle):
            end.transform.rotation += angle
        case .scale(let factor):
            end.transform.scale *= factor
        case .transform(let target):
            end.path = target.path
            end.transform = target.transform
            end.strokeColor = target.strokeColor
            end.strokeWidth = target.strokeWidth
            end.fillColor = target.fillColor
            end.opacity = target.opacity
            end.strokeStart = target.strokeStart
            end.strokeEnd = target.strokeEnd
            end.fillOpacityFactor = target.fillOpacityFactor
        }
        return end
    }

    /// Applies an entry at the given eased progress on top of `state`,
    /// touching only the properties the animation kind owns so that
    /// parallel animations on the same mobject compose.
    private static func apply(_ entry: Entry, easedProgress p: Double, to state: Mobject) -> Mobject {
        var state = state
        let a = entry.startState
        let b = entry.endState
        switch entry.kind {
        case .create:
            state.strokeStart = lerp(a.strokeStart, b.strokeStart, p)
            state.strokeEnd = lerp(a.strokeEnd, b.strokeEnd, p)
            // Fill fades in over the second half of the draw.
            let fillProgress = clamp((p - 0.5) * 2, 0...1)
            state.fillOpacityFactor = lerp(a.fillOpacityFactor, b.fillOpacityFactor, fillProgress)
            // No-op for a plain create (both poles share the same opacity);
            // restores visibility when re-creating a faded-out object.
            state.opacity = lerp(a.opacity, b.opacity, p)
        case .fadeIn(let shift), .fadeOut(let shift):
            state.opacity = lerp(a.opacity, b.opacity, p)
            // A zero-shift fade owns only opacity, so it composes with
            // parallel motion on the same mobject instead of pinning the
            // position to its own (stationary) poles.
            if shift != .zero {
                state.transform.translation = Vec2.lerp(a.transform.translation, b.transform.translation, p)
            }
        case .shift, .move:
            state.transform.translation = Vec2.lerp(a.transform.translation, b.transform.translation, p)
        case .rotate:
            state.transform.rotation = lerp(a.transform.rotation, b.transform.rotation, p)
        case .scale:
            state.transform.scale = Vec2.lerp(a.transform.scale, b.transform.scale, p)
        case .transform:
            if let (pathA, pathB) = entry.alignedPaths {
                state.path = BezierPath.interpolate(pathA, pathB, p)
            } else {
                state.path = p < 1 ? a.path : b.path
            }
            state.transform = Transform2D.lerp(a.transform, b.transform, p)
            state.strokeColor = ManimColor.lerp(a.strokeColor, b.strokeColor, p)
            state.strokeWidth = lerp(a.strokeWidth, b.strokeWidth, p)
            state.fillColor = ManimColor.lerp(a.fillColor, b.fillColor, p)
            state.opacity = lerp(a.opacity, b.opacity, p)
            state.strokeStart = lerp(a.strokeStart, b.strokeStart, p)
            state.strokeEnd = lerp(a.strokeEnd, b.strokeEnd, p)
            state.fillOpacityFactor = lerp(a.fillOpacityFactor, b.fillOpacityFactor, p)
        }
        return state
    }
}
