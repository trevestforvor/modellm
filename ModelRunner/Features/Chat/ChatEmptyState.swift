import SwiftUI

/// Empty state shown when no model is active. SmolLM2 normally auto-installs so this
/// is mostly an edge case (user deleted all models). Tapping the CTA opens ModelsTabView.
struct ChatEmptyState: View {
    /// Optional model name to greet with — nil shows generic copy.
    let modelName: String?
    let onBrowse: () -> Void

    private let accent = Color(hex: "#5E6AD2")

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(accent.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "cpu")
                    .font(.system(size: 36))
                    .foregroundStyle(accent)
            }

            VStack(spacing: 8) {
                Text(headline)
                    .font(.largeTitle.weight(.medium))
                    .fontDesign(.serif)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Your on-device AI")
                    .font(.body)
                    .foregroundStyle(Color(hex: "#9896B0"))
            }
            .padding(.horizontal, 24)

            Button(action: onBrowse) {
                Text("Browse models")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(accent)
                    )
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var headline: String {
        if let name = modelName, !name.isEmpty {
            return "Start chatting with \(name)"
        }
        return "Start chatting"
    }
}

#Preview {
    ZStack {
        Color(hex: "#0D0C18").ignoresSafeArea()
        ChatEmptyState(modelName: "SmolLM2-360M", onBrowse: {})
    }
}
