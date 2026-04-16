import Foundation
import AVFoundation
import Observation

/// Records mono 16 kHz Float32 PCM from the device microphone to a temporary
/// .wav file via AVAudioEngine + AVAudioFile. Used by the speech spike to feed
/// recorded audio into multiple transcription engines.
@MainActor
@Observable
final class AudioRecorder {
    private(set) var isRecording: Bool = false
    var errorMessage: String?

    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var currentURL: URL?
    private var converterTapInstalled = false

    // Target format used by Whisper / Apple SR: 16 kHz mono Float32 PCM
    private let targetSampleRate: Double = 16_000

    func start() async {
        guard !isRecording else { return }
        errorMessage = nil

        // Permission gate (iOS 17+ API).
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            errorMessage = "Microphone permission denied"
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true, options: [])

            let url = makeTempURL()
            currentURL = url

            let input = engine.inputNode
            let inputFormat = input.outputFormat(forBus: 0)

            // Build the on-disk format: 16 kHz mono Float32 PCM (.wav container).
            guard let writeFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: targetSampleRate,
                channels: 1,
                interleaved: false
            ) else {
                errorMessage = "Unable to construct write format"
                return
            }

            // AVAudioFile settings — wav, float32, 16 kHz mono.
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: targetSampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]

            let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            audioFile = file

            // Converter from input format → 16 kHz mono float.
            guard let converter = AVAudioConverter(from: inputFormat, to: writeFormat) else {
                errorMessage = "Unable to construct audio converter"
                return
            }

            input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                guard let self else { return }
                let ratio = writeFormat.sampleRate / inputFormat.sampleRate
                let outCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
                guard let outBuffer = AVAudioPCMBuffer(pcmFormat: writeFormat, frameCapacity: outCapacity) else { return }

                final class PullFlag { var done = false }
                let pullFlag = PullFlag()
                let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                    if pullFlag.done {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    pullFlag.done = true
                    outStatus.pointee = .haveData
                    return buffer
                }

                var convError: NSError?
                converter.convert(to: outBuffer, error: &convError, withInputFrom: inputBlock)
                if convError != nil { return }

                // AVAudioFile.write is not Sendable across actors; hop to main where
                // the file lives.
                let captured = outBuffer
                Task { @MainActor [weak self] in
                    guard let self, let file = self.audioFile else { return }
                    try? file.write(from: captured)
                }
            }
            converterTapInstalled = true

            engine.prepare()
            try engine.start()
            isRecording = true
        } catch {
            errorMessage = "Recorder failed to start: \(error.localizedDescription)"
            cleanupAfterFailure()
        }
    }

    /// Stop recording and return the URL of the recorded .wav (or nil if nothing was captured).
    func stop() -> URL? {
        guard isRecording else { return nil }

        if converterTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            converterTapInstalled = false
        }
        engine.stop()
        audioFile = nil
        isRecording = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Non-fatal.
        }

        let url = currentURL
        currentURL = nil
        return url
    }

    private func cleanupAfterFailure() {
        if converterTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            converterTapInstalled = false
        }
        if engine.isRunning { engine.stop() }
        audioFile = nil
        currentURL = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func makeTempURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
        let name = "stt_spike_\(UUID().uuidString).wav"
        return dir.appendingPathComponent(name)
    }
}
