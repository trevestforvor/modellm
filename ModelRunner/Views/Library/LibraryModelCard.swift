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
                    .font(.appTitle)
                    .foregroundStyle(Color.appGood)
            } else {
                Image(systemName: "circle")
                    .font(.appTitle)
                    .foregroundStyle(Color.appTextTertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Model name
                Text(model.displayName)
                    .font(.appBodyEmphasized)
                    .lineLimit(2)

                // Quantization + file size
                HStack(spacing: 8) {
                    QuantizationBadge(quantization: model.quantization)

                    Text(model.formattedSize)
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextSecondary)
                }

                // Last used + conversation count (D-08)
                HStack(spacing: 8) {
                    Text(model.relativeLastUsed)
                        .font(.appCaption)
                        .foregroundStyle(Color.appTextTertiary)

                    if model.conversationCount > 0 {
                        Text("·")
                            .foregroundStyle(Color.appTextTertiary)
                        Text("\(model.conversationCount) chat\(model.conversationCount == 1 ? "" : "s")")
                            .font(.appCaption)
                            .foregroundStyle(Color.appTextTertiary)
                    }
                }
            }

            Spacer()

            // Chevron hint for tap-to-activate (Phase 4 will also navigate to Chat)
            Image(systemName: "chevron.right")
                .font(.iconMD)
                .foregroundStyle(Color.appTextTertiary)
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
            .font(.appCaption)
            .foregroundStyle(Color.appAccent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.appAccent.opacity(0.12))
            )
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
