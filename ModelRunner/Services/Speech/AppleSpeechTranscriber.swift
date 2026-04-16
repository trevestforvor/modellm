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
            request.shouldReportPartialResults = false

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
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    cont.resume(returning: .failure(error))
                    return
                }
                guard let result, result.isFinal else { return }
                cont.resume(returning: .success(result.bestTranscription.formattedString))
            }
        }
    }
}
