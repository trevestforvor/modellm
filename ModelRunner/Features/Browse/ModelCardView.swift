import SwiftUI

struct ModelCardView: View {
    let model: AnnotatedModel

    private let cardBackground = Color(hex: "#0D0C18")
    private let primaryText    = Color(hex: "#EDEDF4")
    private let secondaryText  = Color(hex: "#9896B0")

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                // Model name
                Text(model.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(primaryText)
                    .lineLimit(1)

                // Metadata row: params · quant · size · downloads
                Text(metadataText)
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Tok/s badge — primaryResult is the best compatible variant
            if let primary = model.primaryResult {
                ToksBadgeView(result: primary.result)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardBackground)
        )
        .accessibilityElement(children: .combine)
    }

    // "7B · Q4_K_M · 4.1 GB · 12.4K downloads"
    private var metadataText: String {
        guard let variant = model.primaryResult else { return model.displayName }
        var parts: [String] = []

        if let params = variant.metadata.parameterCount {
            let billions = Double(params) / 1_000_000_000
            if billions >= 1 {
                parts.append(String(format: "%.0fB", billions))
            } else {
                parts.append(String(format: "%.1fB", billions))
            }
        }

        if variant.quantType != .unknown {
            parts.append(variant.quantType.rawValue)
        }

        parts.append(variant.formattedFileSize)
        parts.append("\(model.downloadCount.formattedDownloadCount) downloads")

        return parts.joined(separator: " · ")
    }
}

#Preview {
    VStack(spacing: 8) {
        Text("ModelCardView Preview")
            .foregroundStyle(.white)
    }
    .padding()
    .background(Color(hex: "#0F0E1A"))
}
