import Testing
@testable import PicoManim

@Suite("Rate functions")
struct RateFunctionTests {
    private let easings: [RateFunction] = [.linear, .smooth, .smootherstep, .easeIn, .easeOut, .easeInOut]

    @Test func standardEasingsHitEndpoints() {
        for easing in easings {
            #expect(abs(easing.apply(0)) < 1e-12)
            #expect(abs(easing.apply(1) - 1) < 1e-12)
        }
    }

    @Test func standardEasingsAreMonotonic() {
        for easing in easings {
            var previous = -Double.infinity
            for step in 0...100 {
                let value = easing.apply(Double(step) / 100)
                #expect(value >= previous - 1e-12)
                previous = value
            }
        }
    }

    @Test func inputIsClamped() {
        #expect(RateFunction.linear.apply(-0.5) == 0)
        #expect(RateFunction.linear.apply(1.5) == 1)
    }

    @Test func smoothIsSymmetricAroundHalf() {
        #expect(abs(RateFunction.smooth.apply(0.5) - 0.5) < 1e-12)
        let low = RateFunction.smooth.apply(0.2)
        let high = RateFunction.smooth.apply(0.8)
        #expect(abs((low + high) - 1) < 1e-12)
    }

    @Test func smoothMatchesManimReferenceValues() {
        // Manim's smooth(t) = normalized sigmoid(10(t - 0.5)):
        // smooth(0.25) ≈ 0.0701037, smooth(0.75) ≈ 0.9298963.
        #expect(abs(RateFunction.smooth.apply(0.25) - 0.0701037) < 1e-6)
        #expect(abs(RateFunction.smooth.apply(0.75) - 0.9298963) < 1e-6)
    }

    @Test func smootherstepIsTheQuintic() {
        // 6t^5 - 15t^4 + 10t^3 at 0.25 = 0.103515625.
        #expect(abs(RateFunction.smootherstep.apply(0.25) - 0.103515625) < 1e-12)
        #expect(abs(RateFunction.smootherstep.apply(0.5) - 0.5) < 1e-12)
    }

    @Test func thereAndBackReturnsToStart() {
        #expect(abs(RateFunction.thereAndBack.apply(0)) < 1e-12)
        #expect(abs(RateFunction.thereAndBack.apply(1)) < 1e-12)
        #expect(abs(RateFunction.thereAndBack.apply(0.5) - 1) < 1e-12)
    }

    @Test func customFunctionIsUsed() {
        let easing = RateFunction.custom { $0 * $0 }
        #expect(abs(easing.apply(0.5) - 0.25) < 1e-12)
    }
}
