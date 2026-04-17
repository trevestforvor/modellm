import SwiftUI

/// Persistent download progress bar — visible across all screens while a download is active.
/// Design intent: unobtrusive, like Apple Music's download indicator (D-01).
/// Height: 64pt. Sits above the tab bar via safeAreaInset in ContentView (P-08).
struct DownloadProgressBar: View {
    let state: DownloadState
    let onCancel: () -> Void

    private var modelName: String {
        state.modelName ?? "Downloading..."
    }

    private var progress: Double {
        if case .downloading(_, let p, _, _, _) = state { return p }
        return 0
    }

    private var throughput: Double? {
        if case .downloading(_, _, _, _, let t) = state { return t }
        return nil
    }

    private var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Divider at top of bar
            Divider()

            HStack(spacing: 12) {
                // Download icon
                Image(systemName: isPaused ? "pause.circle.fill" : "arrow.down.circle.fill")
                    .font(.iconXL)
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.pulse, isActive: !isPaused)

                // Model name + progress stats
                VStack(alignment: .leading, spacing: 2) {
                    Text(modelName)
                        .font(.appSubheadline)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(Color.accentColor)

                        // Throughput
                        Text(DownloadService.formattedThroughput(throughput))
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextSecondary)
                            .monospacedDigit()
                            .frame(width: 60, alignment: .trailing)
                    }
                }

                // Cancel button
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.iconXL)
                        .foregroundStyle(Color.appTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(height: 64)
        }
        .background(Color.appSurface)
    }
}

#Preview("Downloading") {
    VStack {
        Spacer()
        DownloadProgressBar(
            state: .downloading(
                modelName: "Llama 3.2 3B Instruct",
                progress: 0.42,
                bytesWritten: 1_428_000_000,
                totalBytes: 3_400_000_000,
                throughput: 4_200_000
            ),
            onCancel: {}
        )
    }
}

#Preview("Paused") {
    VStack {
        Spacer()
        DownloadProgressBar(
            state: .paused(modelName: "Mistral 7B", bytesWritten: 2_000_000_000),
            onCancel: {}
        )
    }
}
