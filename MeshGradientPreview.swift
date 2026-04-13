import SwiftUI

// Run this in Xcode Previews or a Swift Playground to see the MeshGradient

struct MeshGradientPreview: View {
    var body: some View {
        ZStack {
            // MARK: - Mesh Gradient Background
            MeshGradient(
                width: 3, height: 3,
                points: [
                    // Top row
                    SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                    // Middle row
                    SIMD2(0.0, 0.5), SIMD2(0.5, 0.5), SIMD2(1.0, 0.5),
                    // Bottom row
                    SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
                ],
                colors: [
                    // Top row: sapphire -> near-black -> teal
                    Color(hex: 0x0E1428), Color(hex: 0x0C0B14), Color(hex: 0x0C1A1E),
                    // Middle row: violet -> near-black -> sapphire
                    Color(hex: 0x14102A), Color(hex: 0x0D0C16), Color(hex: 0x0B1220),
                    // Bottom row: near-black -> teal -> violet
                    Color(hex: 0x0C0B14), Color(hex: 0x0A1319), Color(hex: 0x120E22)
                ]
            )
            .ignoresSafeArea()

            // MARK: - Content Layer
            ScrollView {
                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color(hex: 0x6B6980))
                            .font(.system(size: 15))
                        Text("Search models...")
                            .foregroundStyle(Color(hex: 0x6B6980))
                            .font(.system(size: 15))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hex: 0x1A1928).opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // Recommendations header
                    HStack {
                        Text("Best for Your Device")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xEDEDF4))
                        Spacer()
                        Text("See All")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: 0x8B7CF0))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                    // Horizontal scroll recommendations
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            modelCard(
                                name: "Qwen3-4B-GGUF",
                                author: "Qwen",
                                size: "2.5 GB",
                                params: "4B",
                                quant: "Q4_K_M",
                                tokSec: "~32 tok/s",
                                downloads: "2.1M",
                                isGreen: true
                            )
                            modelCard(
                                name: "Gemma-3-3B-GGUF",
                                author: "Google",
                                size: "1.8 GB",
                                params: "3B",
                                quant: "Q4_K_M",
                                tokSec: "~38 tok/s",
                                downloads: "890K",
                                isGreen: true
                            )
                            modelCard(
                                name: "Phi-4-mini-GGUF",
                                author: "Microsoft",
                                size: "2.2 GB",
                                params: "3.8B",
                                quant: "Q4_K_M",
                                tokSec: "~28 tok/s",
                                downloads: "1.4M",
                                isGreen: true
                            )
                        }
                        .padding(.horizontal, 16)
                    }

                    // All Models header
                    HStack {
                        Text("All Models")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xEDEDF4))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                    // Vertical model list
                    VStack(spacing: 8) {
                        modelCard(
                            name: "Mistral-7B-Instruct-v0.3-GGUF",
                            author: "MistralAI",
                            size: "4.1 GB",
                            params: "7B",
                            quant: "Q4_K_M",
                            tokSec: "~12 tok/s",
                            downloads: "5.7M",
                            isGreen: false
                        )
                        modelCard(
                            name: "DeepSeek-R1-Distill-Qwen-7B",
                            author: "DeepSeek",
                            size: "4.7 GB",
                            params: "7B",
                            quant: "Q4_K_M",
                            tokSec: "~10 tok/s",
                            downloads: "4.3M",
                            isGreen: false
                        )
                        modelCard(
                            name: "Llama-3.1-8B-Instruct-GGUF",
                            author: "Meta",
                            size: "4.9 GB",
                            params: "8B",
                            quant: "Q4_K_M",
                            tokSec: "~8 tok/s",
                            downloads: "8.1M",
                            isGreen: false
                        )
                        modelCard(
                            name: "Gemma-3-1B-GGUF",
                            author: "Google",
                            size: "0.7 GB",
                            params: "1B",
                            quant: "Q4_K_M",
                            tokSec: "~55 tok/s",
                            downloads: "520K",
                            isGreen: true
                        )
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Model Card

    func modelCard(
        name: String, author: String, size: String,
        params: String, quant: String, tokSec: String,
        downloads: String, isGreen: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top: name + badge
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
                // Tok/s badge
                Text(tokSec)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isGreen ? Color(hex: 0x34D399) : Color(hex: 0xFBBF24))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        (isGreen ? Color(hex: 0x34D399) : Color(hex: 0xFBBF24))
                            .opacity(0.12)
                    )
                    .clipShape(Capsule())
            }

            // Meta row
            HStack(spacing: 0) {
                Text(size)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0x9896B0))
                dividerDot
                Text(params)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0x9896B0))
                dividerDot
                Text(quant)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0x9896B0))
            }

            // Downloads
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 11))
                Text("\(downloads) downloads")
                    .font(.system(size: 12))
            }
            .foregroundStyle(Color(hex: 0x6B6980))
        }
        .padding(16)
        .frame(minWidth: 280, alignment: .leading)
        .background(Color(hex: 0x1A1928).opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    var dividerDot: some View {
        Text(" · ")
            .font(.system(size: 13))
            .foregroundStyle(Color(hex: 0x6B6980))
    }
}

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

// MARK: - Preview

#Preview("ModelRunner Browse") {
    MeshGradientPreview()
}

#Preview("Gradient Only") {
    MeshGradient(
        width: 3, height: 3,
        points: [
            SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
            SIMD2(0.0, 0.5), SIMD2(0.5, 0.5), SIMD2(1.0, 0.5),
            SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
        ],
        colors: [
            Color(hex: 0x0E1428), Color(hex: 0x0C0B14), Color(hex: 0x0C1A1E),
            Color(hex: 0x14102A), Color(hex: 0x0D0C16), Color(hex: 0x0B1220),
            Color(hex: 0x0C0B14), Color(hex: 0x0A1319), Color(hex: 0x120E22)
        ]
    )
    .ignoresSafeArea()
    .preferredColorScheme(.dark)
}

#Preview("Gradient - Brighter Variant") {
    MeshGradient(
        width: 3, height: 3,
        points: [
            SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
            SIMD2(0.0, 0.5), SIMD2(0.5, 0.5), SIMD2(1.0, 0.5),
            SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
        ],
        colors: [
            Color(hex: 0x121A38), Color(hex: 0x0F0E1C), Color(hex: 0x102028),
            Color(hex: 0x1C1640), Color(hex: 0x100F1E), Color(hex: 0x101828),
            Color(hex: 0x0F0E1C), Color(hex: 0x0E1A24), Color(hex: 0x181232)
        ]
    )
    .ignoresSafeArea()
    .preferredColorScheme(.dark)
}
