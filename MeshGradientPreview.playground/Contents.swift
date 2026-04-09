import SwiftUI
import PlaygroundSupport

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Mesh Gradient Background

struct ModelRunnerGradient: View {
    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                SIMD2(0.0, 0.5), SIMD2(0.5, 0.5), SIMD2(1.0, 0.5),
                SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
            ],
            colors: [
                // Top row: sapphire -> dark base -> teal
                Color(hex: 0x172440), Color(hex: 0x0F0E1A), Color(hex: 0x122A32),
                // Middle row: violet -> dark base -> deep blue
                Color(hex: 0x221942), Color(hex: 0x110F1C), Color(hex: 0x141E3A),
                // Bottom row: dark base -> teal-blue -> violet
                Color(hex: 0x0F0E1A), Color(hex: 0x12242C), Color(hex: 0x1C153E)
            ]
        )
    }
}

// MARK: - Model Card

enum CardStyle {
    case current      // #1A1928 at 75% — what we have now
    case solidDark    // #111020 solid — dark, no opacity
    case solidDarker  // #0D0C18 solid — near-black, barely visible edge
}

struct ModelCard: View {
    let name: String
    let author: String
    let size: String
    let params: String
    let quant: String
    let tokSec: String
    let downloads: String
    let isGreen: Bool
    var style: CardStyle = .current

    var badgeColor: Color { isGreen ? Color(hex: 0x34D399) : Color(hex: 0xFBBF24) }

    var cardBackground: some ShapeStyle {
        switch style {
        case .current:     return AnyShapeStyle(Color(hex: 0x1A1928).opacity(0.75))
        case .solidDark:   return AnyShapeStyle(Color(hex: 0x111020))
        case .solidDarker: return AnyShapeStyle(Color(hex: 0x0D0C18))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xEDEDF4))
                        .lineLimit(2)
                    Text(author)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: 0x9896B0))
                }
                Spacer()
                Text(tokSec)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(badgeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badgeColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: 0) {
                Text(size)
                dot
                Text(params)
                dot
                Text(quant)
            }
            .font(.system(size: 13))
            .foregroundStyle(Color(hex: 0x9896B0))

            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 11))
                Text("\(downloads) downloads")
                    .font(.system(size: 12))
            }
            .foregroundStyle(Color(hex: 0x6B6980))
        }
        .padding(16)
        .frame(minWidth: 270, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    var dot: some View {
        Text(" · ")
            .font(.system(size: 13))
            .foregroundStyle(Color(hex: 0x6B6980))
    }
}

// MARK: - Browse Screen

struct BrowseScreen: View {
    let cardStyle: CardStyle
    let label: String

    var body: some View {
        ZStack {
            ModelRunnerGradient()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Label
                    Text(label)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: 0x8B7CF0))
                        .padding(.top, 8)

                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color(hex: 0x6B6980))
                        Text("Search models...")
                            .foregroundStyle(Color(hex: 0x6B6980))
                        Spacer()
                    }
                    .font(.system(size: 15))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(searchBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    sectionHeader("Best for Your Device")

                    VStack(spacing: 8) {
                        ModelCard(name: "Qwen3-4B-GGUF", author: "Qwen", size: "2.5 GB", params: "4B", quant: "Q4_K_M", tokSec: "~32 tok/s", downloads: "2.1M", isGreen: true, style: cardStyle)
                        ModelCard(name: "Mistral-7B-v0.3-GGUF", author: "MistralAI", size: "4.1 GB", params: "7B", quant: "Q4_K_M", tokSec: "~12 tok/s", downloads: "5.7M", isGreen: false, style: cardStyle)
                        ModelCard(name: "Gemma-3-1B-GGUF", author: "Google", size: "0.7 GB", params: "1B", quant: "Q4_K_M", tokSec: "~55 tok/s", downloads: "520K", isGreen: true, style: cardStyle)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }

    var searchBackground: some ShapeStyle {
        switch cardStyle {
        case .current:     return AnyShapeStyle(Color(hex: 0x1A1928).opacity(0.75))
        case .solidDark:   return AnyShapeStyle(Color(hex: 0x111020))
        case .solidDarker: return AnyShapeStyle(Color(hex: 0x0D0C18))
        }
    }

    func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(hex: 0xEDEDF4))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
}

// MARK: - Set Live View

PlaygroundPage.current.setLiveView(
    BrowseScreen(cardStyle: .solidDarker, label: "")
        .frame(width: 390, height: 844)
)
