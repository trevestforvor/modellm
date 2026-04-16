import SwiftUI

struct SpeechSpikeView: View {
    @State private var viewModel = SpeechSpikeViewModel()
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: $expanded) {
                content
                    .padding(.top, 12)
            } label: {
                Text("SPEECH SPIKE")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#9896B0"))
                    .tracking(0.5)
            }
            .tint(Color(hex: "#9896B0"))
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    viewModel.togglePushToTalk()
                } label: {
                    ZStack {
                        Circle()
                            .fill(viewModel.recorder.isRecording
                                  ? Color(red: 0.95, green: 0.35, blue: 0.40)
                                  : Color(hex: "#8B7CF0"))
                            .frame(width: 64, height: 64)
                        Image(systemName: viewModel.recorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isProcessing)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.recorder.isRecording ? "Recording…" : "Tap mic to start, tap again to stop")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    if let err = viewModel.recorder.errorMessage {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.45))
                    } else if let err = viewModel.errorMessage {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.45))
                    } else {
                        Text("Compares 3 STT engines on the same clip.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#9896B0"))
                    }
                }

                Spacer()

                if !viewModel.lastResults.isEmpty {
                    Button {
                        viewModel.clearResults()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "#9896B0"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            ZStack {
                VStack(spacing: 8) {
                    ForEach(viewModel.lastResults) { result in
                        EngineResultRow(result: result)
                    }
                }
                .padding(.horizontal, 16)

                if viewModel.isProcessing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(Color(hex: "#8B7CF0"))
                        Text("Transcribing…")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#9896B0"))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "#1A1830"))
                    )
                }
            }
        }
    }
}
