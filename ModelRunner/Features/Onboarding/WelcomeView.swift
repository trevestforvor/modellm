import SwiftUI
import SwiftData

// MARK: - Welcome Path

enum WelcomePath {
    /// Guided: best downloaded model pre-selected (or nil → fall back to Browse tab)
    case guided(model: DownloadedModel?)
    /// Skip onboarding — go straight to Browse tab
    case browse
}

// MARK: - WelcomeView

struct WelcomeView: View {
    @Query private var downloadedModels: [DownloadedModel]
    let onComplete: (WelcomePath) -> Void

    private let accent        = Color(hex: "#8B7CF0")
    private let secondaryText = Color(hex: "#9896B0")
    private let meshBase      = Color(hex: "#0F0E1A")

    var body: some View {
        ZStack {
            meshBackground

            VStack(spacing: 0) {
                Spacer()

                // App icon placeholder — 80pt, accent at 15%, cpu SF Symbol
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(accent.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "cpu")
                        .font(.system(size: 36))
                        .foregroundStyle(accent)
                }

                Spacer().frame(height: 24)

                // Title — 28pt bold
                Text("ModelRunner")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer().frame(height: 8)

                // Tagline — 20pt semibold
                Text("Run AI on your iPhone")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer().frame(height: 8)

                // Subtitle — 15pt secondary
                Text("Download open-source models. Chat completely offline.")
                    .font(.system(size: 15))
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                // Buttons stacked vertically
                VStack(spacing: 12) {
                    // Primary: Show Me Around — #8B7CF0 filled
                    Button(action: handleShowMeAround) {
                        Text("Show Me Around")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(accent)
                            )
                    }

                    // Secondary: Get Started — glass material
                    Button(action: { onComplete(.browse) }) {
                        Text("Get Started")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(hex: "#1A1830").opacity(0.6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(Color(hex: "#302E42"), lineWidth: 0.5)
                                    )
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 48)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    // MARK: - Guided path logic

    private func handleShowMeAround() {
        let bestModel = pickBestModel()
        onComplete(.guided(model: bestModel))
    }

    /// Find the smallest downloaded model by file size.
    /// All downloaded models were vetted as compatible before download; no re-check needed.
    /// Falls back to nil if no models are downloaded — caller falls back to Browse tab.
    private func pickBestModel() -> DownloadedModel? {
        downloadedModels.min(by: { $0.fileSizeBytes < $1.fileSizeBytes })
    }

    private var meshBackground: some View {
        AppBackground()
    }
}

// MARK: - Preview

#Preview {
    WelcomeView { _ in }
        .modelContainer(for: DownloadedModel.self, inMemory: true)
}
