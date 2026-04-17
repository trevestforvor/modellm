import SwiftUI

struct ModelCardView: View {
    let model: AnnotatedModel

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.displayName)
                    .font(.appHeadline)
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)

                Text(metadataText)
                    .font(.appSubheadline)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let primary = model.primaryResult {
                ToksBadgeView(result: primary.result)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppCardBackground(cornerRadius: 16))
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
            .foregroundStyle(Color.appTextPrimary)
    }
    .padding()
    .background(Color.appPage)
}
