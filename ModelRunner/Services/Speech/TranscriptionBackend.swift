import Foundation

/// Result of running an audio file through a transcription engine.
/// Named `EngineTranscriptionResult` (not `TranscriptionResult`) to avoid
/// colliding with `WhisperKit.TranscriptionResult`.
struct EngineTranscriptionResult: Sendable, Identifiable {
    let id = UUID()
    let engineID: String
    let text: String
    let wallClockSeconds: Double
    let error: String?  // non-nil if transcription failed
}

protocol TranscriptionBackend: Sendable {
    var id: String { get }
    var displayName: String { get }
    func transcribe(audioURL: URL) async -> EngineTranscriptionResult
}
