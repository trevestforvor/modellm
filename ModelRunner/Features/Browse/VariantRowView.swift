import SwiftUI

struct VariantRowView: View {
    let variant: AnnotatedVariant

    private let primaryText   = Color(hex: "#EDEDF4")
    private let secondaryText = Color(hex: "#9896B0")

    var body: some View {
        HStack(spacing: 12) {
            // Quantization type — left aligned
            Text(variant.quantType == .unknown ? variant.filename : variant.quantType.rawValue)
                .font(.figtree(.subheadline, weight: .medium))
                .foregroundStyle(primaryText)

            Spacer()

            // File size — SF Mono for data precision (DESIGN.md)
            Text(variant.formattedFileSize)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(secondaryText)

            // Compatibility badge
            ToksBadgeView(result: variant.result)
        }
        .frame(minHeight: 44)
    }
}

#Preview {
    List {
        Text("VariantRowView Preview")
            .foregroundStyle(.white)
    }
    .background(Color(hex: "#0D0C18"))
}
