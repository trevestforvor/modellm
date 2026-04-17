import SwiftUI

/// Library list row for a downloaded model (D-07).
/// Shows: model name, quantization, file size, relative last-used timestamp,
/// conversation count, compatibility tier badge, and active checkmark (D-10).
struct LibraryModelCard: View {
    let model: DownloadedModel

    var body: some View {
        HStack(spacing: 12) {
            // Active model indicator (D-10)
            if model.isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Model name
                Text(model.displayName)
                    .font(.figtree(.body, weight: .medium))
                    .lineLimit(2)

                // Quantization + file size
                HStack(spacing: 8) {
                    QuantizationBadge(quantization: model.quantization)

                    Text(model.formattedSize)
                        .font(.figtree(.caption))
                        .foregroundStyle(.secondary)
                }

                // Last used + conversation count (D-08)
                HStack(spacing: 8) {
                    Text(model.relativeLastUsed)
                        .font(.figtree(.caption))
                        .foregroundStyle(.tertiary)

                    if model.conversationCount > 0 {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("\(model.conversationCount) chat\(model.conversationCount == 1 ? "" : "s")")
                            .font(.figtree(.caption))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Chevron hint for tap-to-activate (Phase 4 will also navigate to Chat)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Quantization Badge

/// Small pill badge for quantization type e.g. "Q4_K_M"
private struct QuantizationBadge: View {
    let quantization: String

    var body: some View {
        Text(quantization)
            .font(.figtree(.caption2, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15))
            .clipShape(Capsule())
    }
}

#Preview {
    let model = DownloadedModel(
        repoId: "bartowski/Llama-3.2-3B-Instruct-GGUF",
        displayName: "Llama 3.2 3B Instruct",
        filename: "Llama-3.2-3B-Instruct-Q4_K_M.gguf",
        quantization: "Q4_K_M",
        fileSizeBytes: 2_019_000_000,
        localPath: "/fake/path"
    )
    List {
        LibraryModelCard(model: model)
    }
}
