import Foundation
import WhisperKit

/// Wraps a single WhisperKit model instance. Lazy init: model is downloaded /
/// loaded on first call. Subsequent transcribes are serialized through the actor.
actor WhisperKitTranscriber: TranscriptionBackend {
    let id: String
    let displayName: String
    private let modelID: String
    private var pipeline: WhisperKit?

    init(id: String, displayName: String, modelID: String) {
        self.id = id
        self.displayName = displayName
        self.modelID = modelID
    }

    private func ensurePipeline() async throws -> WhisperKit {
        if let p = pipeline { return p }
        // WhisperKit will fetch / cache the model from the HF Hub on first use.
        let p = try await WhisperKit(model: modelID, verbose: false, logLevel: .error)
        pipeline = p
        return p
    }

    func transcribe(audioURL: URL) async -> EngineTranscriptionResult {
        let clock = ContinuousClock()
        var captured: String = ""
        var errString: String?

        let elapsed = await clock.measure {
            do {
                let pipe = try await ensurePipeline()
                let results = try await pipe.transcribe(audioPath: audioURL.path)
                captured = results.map(\.text).joined(separator: " ")
            } catch {
                errString = "\(error.localizedDescription)"
            }
        }

        let seconds = Double(elapsed.components.seconds) +
            Double(elapsed.components.attoseconds) / 1e18

        return EngineTranscriptionResult(
            engineID: id,
            text: captured.trimmingCharacters(in: .whitespacesAndNewlines),
            wallClockSeconds: seconds,
            error: errString
        )
    }
}
