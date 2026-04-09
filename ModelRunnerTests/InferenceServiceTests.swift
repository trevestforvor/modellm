import Testing
import Foundation
@testable import ModelRunner

@Suite("InferenceService")
struct InferenceServiceTests {

    @Test("initial state: isLoaded is false")
    func testInitialStateNotLoaded() async {
        let service = InferenceService()
        let loaded = await service.isLoaded
        #expect(!loaded)
    }

    @Test("loadModel with nonexistent file throws modelLoadFailed")
    func testLoadNonexistentModelThrows() async {
        let service = InferenceService()
        let fakeURL = URL(filePath: "/tmp/nonexistent-\(UUID().uuidString).gguf")
        let params = InferenceParams.default(contextWindowCap: 2048)
        do {
            try await service.loadModel(at: fakeURL, params: params)
            Issue.record("Expected modelLoadFailed error — should not reach here")
        } catch InferenceError.modelLoadFailed {
            // expected path
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("generate without loaded model throws noActiveSession")
    func testGenerateWithoutModelThrows() async {
        let service = InferenceService()
        var threwExpectedError = false
        do {
            for try await _ in await service.generate(prompt: "hello") {
                Issue.record("Should not yield tokens without a loaded model")
            }
        } catch InferenceError.noActiveSession {
            threwExpectedError = true
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(threwExpectedError)
    }

    @Test("unloadModel when no model loaded does not crash")
    func testUnloadWithNoModel() async {
        let service = InferenceService()
        await service.unloadModel()
        let loaded = await service.isLoaded
        #expect(!loaded)
    }

    @Test("stopGeneration does not crash when called without active session")
    func testStopGenerationWithoutSession() async {
        let service = InferenceService()
        // Should not crash or throw
        await service.stopGeneration()
        let loaded = await service.isLoaded
        #expect(!loaded)
    }

    @Test("InferenceParams.default uses provided context window cap")
    func testInferenceParamsDefault() {
        let params = InferenceParams.default(contextWindowCap: 4096)
        #expect(params.contextWindowTokens == 4096)
        #expect(params.batchSize == 512)
        #expect(params.gpuLayers == 99)
    }
}
