import Foundation
import Speech

/// Transcribes a recorded audio file using Apple's on-device SFSpeechRecognizer.
/// Free baseline; no model download required (Apple downloads the on-device
/// recognizer model under the hood).
final class AppleSpeechTranscriber: TranscriptionBackend, @unchecked Sendable {
    let id: String = "apple-on-device"
    let displayName: String = "Apple SFSpeechRecognizer (on-device)"

    private let recognizer: SFSpeechRecognizer?
    private var didRequestAuth = false

    init(localeIdentifier: String = "en-US") {
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
    }

    func transcribe(audioURL: URL) async -> EngineTranscriptionResult {
        let clock = ContinuousClock()
        var transcript: String = ""
        var errString: String?

        let elapsed = await clock.measure {
            // Authorization (once).
            if !didRequestAuth {
                didRequestAuth = true
                _ = await Self.requestAuthorization()
            }

            guard let recognizer else {
                errString = "SFSpeechRecognizer unavailable for locale"
                return
            }
            guard recognizer.isAvailable else {
                errString = "Recognizer not currently available"
                return
            }
            guard recognizer.supportsOnDeviceRecognition else {
                errString = "On-device recognition not supported on this device"
                return
            }

            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.requiresOnDeviceRecognition = true
            // Enable partial results so we receive ongoing segments across pauses.
            // On-device recognizer emits isFinal=true for each silence-delimited
            // utterance; we accumulate and return when recognition truly finishes.
            request.shouldReportPartialResults = true
            request.taskHint = .dictation

            let result = await Self.runRecognition(recognizer: recognizer, request: request)
            switch result {
            case .success(let text):
                transcript = text
            case .failure(let err):
                errString = err.localizedDescription
            }
        }

        let seconds = Double(elapsed.components.seconds) +
            Double(elapsed.components.attoseconds) / 1e18

        return EngineTranscriptionResult(
            engineID: id,
            text: transcript.trimmingCharacters(in: .whitespacesAndNewlines),
            wallClockSeconds: seconds,
            error: errString
        )
    }

    private static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
    }

    private static func runRecognition(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechURLRecognitionRequest
    ) async -> Result<String, Error> {
        await withCheckedContinuation { (cont: CheckedContinuation<Result<String, Error>, Never>) in
            let state = RecognitionState(continuation: cont)
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    state.finish(.failure(error))
                    return
                }
                guard let result else { return }
                state.update(text: result.bestTranscription.formattedString,
                             isFinal: result.isFinal)
            }
        }
    }

    /// Accumulates the latest transcription across partial/final callbacks.
    /// Resumes the continuation on a debounce after the most recent update,
    /// so silence-delimited `isFinal=true` segments don't cut transcription short.
    private final class RecognitionState: @unchecked Sendable {
        private let lock = NSLock()
        private var hasResumed = false
        private var latestText: String = ""
        private var sawFinal = false
        private var debounce: DispatchWorkItem?
        private let continuation: CheckedContinuation<Result<String, Error>, Never>

        init(continuation: CheckedContinuation<Result<String, Error>, Never>) {
            self.continuation = continuation
        }

        func update(text: String, isFinal: Bool) {
            lock.lock()
            defer { lock.unlock() }
            guard !hasResumed else { return }
            if text.count >= latestText.count { latestText = text }
            if isFinal { sawFinal = true }
            debounce?.cancel()
            // Shorter debounce once we've seen a final segment; longer while still streaming.
            let delay: TimeInterval = sawFinal ? 0.6 : 1.5
            let work = DispatchWorkItem { [weak self] in self?.resume() }
            debounce = work
            DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: work)
        }

        func finish(_ result: Result<String, Error>) {
            lock.lock()
            defer { lock.unlock() }
            guard !hasResumed else { return }
            hasResumed = true
            debounce?.cancel()
            continuation.resume(returning: result)
        }

        private func resume() {
            lock.lock()
            defer { lock.unlock() }
            guard !hasResumed else { return }
            hasResumed = true
            continuation.resume(returning: .success(latestText))
        }
    }
}
