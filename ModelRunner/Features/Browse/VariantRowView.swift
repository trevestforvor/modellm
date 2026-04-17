import SwiftUI

struct VariantRowView: View {
    let variant: AnnotatedVariant
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Text(variant.quantType == .unknown ? variant.filename : variant.quantType.rawValue)
                .font(.appSubheadline)
                .foregroundStyle(Color.appTextPrimary)

            Spacer()

            Text(variant.formattedFileSize)
                .font(.appMonoSmall)
                .foregroundStyle(Color.appTextSecondary)

            ToksBadgeView(result: variant.result)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.iconMD)
                .foregroundStyle(isSelected ? Color.appAccent : Color.appTextTertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    List {
        Text("VariantRowView Preview")
            .foregroundStyle(Color.appTextPrimary)
    }
    .background(Color.appPage)
}
