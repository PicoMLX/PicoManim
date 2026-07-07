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
    /// The most recent nonzero opacity each mobject carried on the build
    /// cursor, so hide/show cycles (fadeOut then fadeIn/create) restore the
    /// style opacity a transform may have set, not the authored value.
    private var lastVisibleOpacities: [Mobject.ID: Double] = [:]
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

    /// Plays several animation lists (for example group animations, which
    /// expand to one animation per child) together in one parallel group.
    public mutating func play(_ animationGroups: [ManimAnimation]...) {
        play(animationGroups.flatMap { $0 })
    }

    /// Plays a group animation together with individual animations in one
    /// parallel group: `scene.play(.create(row), .shift(dot, by: .up))`.
    /// For arbitrary mixes, concatenate arrays: `play(.create(a) + [b, c])`.
    public mutating func play(_ animationGroup: [ManimAnimation], _ animations: ManimAnimation...) {
        play(animationGroup + animations)
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
        // Buffered so the group's entries can be appended in chronological
        // order below, whatever order the caller listed them in.
        var newEntries: [Entry] = []

        for animation in animations {
            let id = animation.mobject.id
            let entryStart = groupStart + max(0, animation.delay)
            // Group-relative kinds carry their sibling mobjects; resolve the
            // pivot or delta against the live scene state now, so a group
            // animation acts on wherever the group actually is, not on the
            // (possibly stale) group value the factory captured.
            let kind = Self.resolvingGroupKind(animation.kind, states: groupStartStates)
            let startState: Mobject
            // The state the mobject is in as this group begins; the authored
            // value for a mobject this play call introduces.
            let preGroup = groupStartStates[id] ?? animation.mobject
            if groupStartStates[id] != nil {
                // Re-introducing animations (create, fadeIn) restart from a
                // hidden version of wherever the mobject currently is.
                startState = Self.introducedStartState(for: kind, from: preGroup)
            } else {
                // First appearance: seed time zero with a hidden state so the
                // mobject doesn't exist on screen before this point.
                let hidden = Self.initialState(for: kind, from: animation.mobject)
                initialStates[id] = hidden
                order.append(id)
                // A sibling animation in this same group starts from the
                // authored state, not from this animation's end.
                groupStartStates[id] = animation.mobject
                switch kind {
                case .create, .fadeIn:
                    startState = hidden
                default:
                    // Non-revealing animation on a brand-new mobject: show it
                    // instantly (like `add`) and animate from there.
                    let visible = animation.mobject
                    newEntries.append(Entry(
                        startTime: entryStart,
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
                startTime: entryStart,
                duration: max(0, animation.duration),
                rate: animation.rate,
                kind: kind,
                targetID: id,
                startState: startState,
                endState: startState,
                alignedPaths: nil
            )
            if case .transform(let target) = kind {
                entry.alignedPaths = startState.path.aligned(with: target.path)
            }
            // The opacity a revealing animation should end at: the current
            // style opacity, or - when currently hidden - the last opacity
            // the object was visible with (falling back to the authored one).
            let revealOpacity = preGroup.opacity > 0
                ? preGroup.opacity
                : (lastVisibleOpacities[id] ?? animation.mobject.opacity)
            entry.endState = Self.endState(
                for: kind,
                from: startState,
                preGroup: preGroup,
                revealOpacity: revealOpacity
            )
            newEntries.append(entry)

            groupDuration = max(groupDuration, max(0, animation.delay) + entry.duration)
        }
        // Delayed animations can start after siblings listed later in the
        // call. The snapshot fold applies entries in array order and lets a
        // completed entry keep asserting its final value, so the timeline
        // must stay chronological or an early-listed delayed animation
        // would be overwritten by an already-finished sibling. Ties keep
        // their listed order (later wins, as documented). Groups only ever
        // start at or after every entry of the previous group, so sorting
        // within the group keeps the whole array sorted.
        let indexed = newEntries.enumerated().sorted {
            ($0.element.startTime, $0.offset) < ($1.element.startTime, $1.offset)
        }
        entries.append(contentsOf: indexed.map { $0.element })
        // Advance the build cursor in the same chronological order the
        // snapshot fold uses (for rate functions like `thereAndBack` the
        // state left behind is rate(1), not the end pole), so `state(of:)`
        // and later plays agree with what the timeline actually shows when
        // delayed siblings drive the same property.
        for (_, entry) in indexed {
            let id = entry.targetID
            currentStates[id] = Self.apply(
                entry,
                easedProgress: entry.rate.apply(1),
                to: currentStates[id] ?? entry.startState
            )
            if let opacity = currentStates[id]?.opacity, opacity > 0 {
                lastVisibleOpacities[id] = opacity
            }
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
    private static func initialState(for kind: ManimAnimation.Kind, from mobject: Mobject) -> Mobject {
        switch kind {
        case .create, .fadeIn:
            return introducedStartState(for: kind, from: mobject)
        default:
            // Hidden until the instant reveal entry at the play time fires.
            var state = mobject
            state.opacity = 0
            return state
        }
    }

    /// Rewrites group-relative kinds (`groupMove`/`groupRotate`/`groupScale`)
    /// into concrete ones by resolving the group's bounding-box center from
    /// the live scene state (falling back to the carried snapshot for
    /// mobjects the scene has not met yet). Everything else passes through.
    private static func resolvingGroupKind(
        _ kind: ManimAnimation.Kind,
        states: [Mobject.ID: Mobject]
    ) -> ManimAnimation.Kind {
        func liveCenter(_ members: [Mobject]) -> Vec2 {
            MobjectGroup(members.map { states[$0.id] ?? $0 }).center
        }
        switch kind {
        case .groupMove(let point, let members):
            return .shift(by: point - liveCenter(members))
        case .groupRotate(let angle, let members):
            return .rotateAbout(pivot: liveCenter(members), by: angle)
        case .groupScale(let factor, let members):
            return .scaleAbout(pivot: liveCenter(members), by: factor)
        default:
            return kind
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
        for kind: ManimAnimation.Kind,
        from start: Mobject,
        preGroup: Mobject,
        revealOpacity: Double
    ) -> Mobject {
        var end = start
        switch kind {
        case .create:
            end.strokeStart = 0
            end.strokeEnd = 1
            end.fillOpacityFactor = 1
            // Like fadeIn, create is a revealing animation: it ends at the
            // opacity the object should be visible with.
            end.opacity = revealOpacity
        case .fadeIn(let shift):
            end.opacity = revealOpacity
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
        case .rotateAbout(let pivot, let angle):
            end.transform.rotation += angle
            end.transform.translation = pivot + (start.transform.translation - pivot).rotated(by: angle)
        case .scale(let factor):
            end.transform.scale *= factor
        case .scaleAbout(let pivot, let factor):
            end.transform.scale *= factor
            end.transform.translation = pivot + (start.transform.translation - pivot) * factor
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
        case .groupMove, .groupRotate, .groupScale:
            // Rewritten into concrete kinds by play(); an unresolved one
            // reaching evaluation is inert rather than a crash.
            break
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
        case .rotateAbout(let pivot, let angle):
            state.transform.rotation = lerp(a.transform.rotation, b.transform.rotation, p)
            // The position orbits the pivot along a circular arc, not the
            // chord between the poles.
            state.transform.translation = pivot
                + (a.transform.translation - pivot).rotated(by: angle * p)
        case .scale:
            state.transform.scale = Vec2.lerp(a.transform.scale, b.transform.scale, p)
        case .scaleAbout(let pivot, let factor):
            state.transform.scale = Vec2.lerp(a.transform.scale, b.transform.scale, p)
            state.transform.translation = pivot
                + (a.transform.translation - pivot) * lerp(1, factor, p)
        case .transform:
            // At the poles, return the exact (unaligned) paths: the aligned
            // copies are structurally padded, and for an empty target the
            // padding would leave phantom degenerate geometry behind.
            if p <= 0 {
                state.path = a.path
            } else if p >= 1 {
                state.path = b.path
            } else if let (pathA, pathB) = entry.alignedPaths {
                state.path = BezierPath.interpolate(pathA, pathB, p)
            } else {
                state.path = a.path
            }
            state.transform = Transform2D.lerp(a.transform, b.transform, p)
            state.strokeColor = ManimColor.lerp(a.strokeColor, b.strokeColor, p)
            state.strokeWidth = lerp(a.strokeWidth, b.strokeWidth, p)
            state.fillColor = ManimColor.lerp(a.fillColor, b.fillColor, p)
            state.opacity = lerp(a.opacity, b.opacity, p)
            state.strokeStart = lerp(a.strokeStart, b.strokeStart, p)
            state.strokeEnd = lerp(a.strokeEnd, b.strokeEnd, p)
            state.fillOpacityFactor = lerp(a.fillOpacityFactor, b.fillOpacityFactor, p)
        case .groupMove, .groupRotate, .groupScale:
            // Rewritten into concrete kinds by play(); an unresolved one
            // reaching evaluation is inert rather than a crash.
            break
        }
        return state
    }
}
