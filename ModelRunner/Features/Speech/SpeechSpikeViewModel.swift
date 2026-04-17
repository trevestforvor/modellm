import Foundation
import Observation

@MainActor
@Observable
final class SpeechSpikeViewModel {
    let recorder: AudioRecorder
    let transcribers: [any TranscriptionBackend]

    var lastResults: [EngineTranscriptionResult] = []
    var isProcessing: Bool = false
    var errorMessage: String?

    init() {
        self.recorder = AudioRecorder()
        self.transcribers = [
            WhisperKitTranscriber(
                id: "whisperkit-distil-large-v3-turbo",
                displayName: "WhisperKit · distil-large-v3-turbo",
                modelID: "distil-whisper_distil-large-v3_turbo_600MB"
            ),
            WhisperKitTranscriber(
                id: "whisperkit-base-en",
                displayName: "WhisperKit · base.en",
                modelID: "openai_whisper-base.en"
            ),
            AppleSpeechTranscriber(),
        ]
    }

    /// Toggle the recorder. Tap once to start, tap again to stop and process.
    func togglePushToTalk() {
        if recorder.isRecording {
            stopAndProcess()
        } else {
            Task { await recorder.start() }
        }
    }

    private func stopAndProcess() {
        guard let url = recorder.stop() else {
            errorMessage = "No audio captured"
            return
        }

        isProcessing = true
        errorMessage = nil
        lastResults = []
        let backends = transcribers
        let orderIndex: [String: Int] = Dictionary(uniqueKeysWithValues:
            backends.enumerated().map { ($1.id, $0) }
        )

        Task { [weak self] in
            let collected = await withTaskGroup(of: EngineTranscriptionResult.self) { group -> [EngineTranscriptionResult] in
                for backend in backends {
                    group.addTask {
                        await backend.transcribe(audioURL: url)
                    }
                }
                var out: [EngineTranscriptionResult] = []
                for await r in group { out.append(r) }
                return out
            }
            let sorted = collected.sorted { lhs, rhs in
                (orderIndex[lhs.engineID] ?? .max) < (orderIndex[rhs.engineID] ?? .max)
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.lastResults = sorted
                self.isProcessing = false
            }
        }
    }

    func clearResults() {
        lastResults = []
        errorMessage = nil
    }
}
