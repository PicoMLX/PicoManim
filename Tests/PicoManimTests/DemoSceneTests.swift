import Testing
@testable import PicoManim

@Suite("Demo scene")
struct DemoSceneTests {
    @Test func demoSceneEvaluatesEverywhere() {
        let scene = ManimScene.demo
        #expect(scene.duration > 0)
        for step in 0...20 {
            let time = scene.duration * Double(step) / 20
            let snapshot = scene.snapshot(at: time)
            #expect(!snapshot.isEmpty)
        }
    }

    @Test func demoSceneEndsWithEverythingFadedOut() {
        let scene = ManimScene.demo
        let final = scene.snapshot(at: scene.duration)
        #expect(final.allSatisfy { $0.opacity == 0 })
    }
}
