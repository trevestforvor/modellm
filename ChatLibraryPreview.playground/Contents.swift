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

// MARK: - Design Tokens

private enum DS {
    static let cardBg = Color(hex: 0x0D0C18)
    static let bubbleAssistant = Color(hex: 0x1A1830)
    static let bubbleUser = Color(hex: 0x8B7CF0)
    static let inputFieldBg = Color(hex: 0x1A1830)

    static let textPrimary = Color(hex: 0xEDEDF4)
    static let textSecondary = Color(hex: 0x9896B0)
    static let textTertiary = Color(hex: 0x6B6980)

    static let accent = Color(hex: 0x8B7CF0)
    static let green = Color(hex: 0x34D399)
    static let amber = Color(hex: 0xFBBF24)
    static let border = Color(hex: 0x302E42)
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
                Color(hex: 0x172440), Color(hex: 0x0F0E1A), Color(hex: 0x122A32),
                Color(hex: 0x221942), Color(hex: 0x110F1C), Color(hex: 0x141E3A),
                Color(hex: 0x0F0E1A), Color(hex: 0x12242C), Color(hex: 0x1C153E)
            ]
        )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - CHAT VIEW (Phase 4)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct ChatScreen: View {
    var body: some View {
        ZStack {
            ModelRunnerGradient().ignoresSafeArea()

            VStack(spacing: 0) {
                chatNavBar
                ScrollView {
                    VStack(spacing: 12) {
                        userBubble("What are the main differences between supervised and unsupervised learning?")

                        assistantBubble("""
                        Supervised Learning uses labeled training data where the correct output is known. The model learns to map inputs to outputs.

                        Unsupervised Learning works with unlabeled data and finds hidden patterns or structures on its own.

                        Key differences:
                        • Data: Labeled vs unlabeled
                        • Goal: Prediction vs pattern discovery
                        • Examples: Classification, regression vs clustering
                        """, tokSec: nil)

                        userBubble("Can you give me a real-world example of each?")

                        assistantBubble("""
                        Supervised: Email spam detection. The model trains on emails labeled "spam" or "not spam" and learns to classify new ones.

                        Unsupervised: Customer segmentation. Given purchase data with no labels, the algorithm groups customers by buying patterns.
                        """, tokSec: nil)

                        userBubble("What about reinforcement learning?")

                        streamingBubble(
                            "Reinforcement learning is a third paradigm where an agent learns by interacting with an environment. Instead of learning from a dataset, it learns from rewards and penalties received for its actions.\n\nThink of it like training a",
                            tokSec: "~24 tok/s"
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                chatInputBar(isGenerating: true)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Nav Bar

    var chatNavBar: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Chat")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DS.textPrimary)
                    Text("Qwen3-4B · Q4_K_M")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.textSecondary)
                }
                Spacer()
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(DS.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Rectangle().fill(DS.border).frame(height: 0.5)
        }
        .background(DS.cardBg.opacity(0.9))
    }

    // MARK: User Bubble

    func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 60)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(DS.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(DS.bubbleUser)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: 16,
                        bottomTrailingRadius: 4,
                        topTrailingRadius: 16
                    )
                )
        }
    }

    // MARK: Assistant Bubble

    func assistantBubble(_ text: String, tokSec: String?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(DS.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(DS.bubbleAssistant)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 16,
                            bottomLeadingRadius: 4,
                            bottomTrailingRadius: 16,
                            topTrailingRadius: 16
                        )
                    )

                if let tok = tokSec {
                    Text(tok)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DS.textTertiary)
                        .padding(.leading, 8)
                }
            }
            Spacer(minLength: 60)
        }
    }

    // MARK: Streaming Bubble

    func streamingBubble(_ text: String, tokSec: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .bottom, spacing: 0) {
                    Text(text)
                        .font(.system(size: 15))
                        .foregroundStyle(DS.textPrimary)
                    Rectangle()
                        .fill(DS.accent)
                        .frame(width: 2, height: 16)
                        .padding(.bottom, 2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(DS.bubbleAssistant)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: 4,
                        bottomTrailingRadius: 16,
                        topTrailingRadius: 16
                    )
                )

                Text(tokSec)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.green)
                    .padding(.leading, 8)
            }
            Spacer(minLength: 60)
        }
    }

    // MARK: Input Bar

    func chatInputBar(isGenerating: Bool) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(DS.border).frame(height: 0.5)
            HStack(spacing: 12) {
                HStack {
                    Text(isGenerating ? "" : "Message...")
                        .font(.system(size: 15))
                        .foregroundStyle(DS.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(DS.inputFieldBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DS.border, lineWidth: 0.5)
                )

                if isGenerating {
                    ZStack {
                        Circle().fill(DS.amber).frame(width: 34, height: 34)
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.black)
                    }
                } else {
                    ZStack {
                        Circle().fill(DS.accent.opacity(0.4)).frame(width: 34, height: 34)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DS.textPrimary.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(DS.cardBg.opacity(0.95))
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - LIBRARY TAB (Phase 3)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct LibraryScreen: View {
    var body: some View {
        ZStack {
            ModelRunnerGradient().ignoresSafeArea()

            VStack(spacing: 0) {
                libraryNavBar

                ScrollView {
                    VStack(spacing: 0) {
                        storageSummary

                        VStack(spacing: 8) {
                            libraryCard(
                                name: "Qwen3-4B-GGUF", quant: "Q4_K_M", size: "2.5 GB",
                                tokSec: "~32 tok/s", isGreen: true,
                                lastUsed: "2 hours ago", conversations: 14, isActive: true
                            )
                            libraryCard(
                                name: "Gemma-3-3B-GGUF", quant: "Q4_K_M", size: "1.8 GB",
                                tokSec: "~38 tok/s", isGreen: true,
                                lastUsed: "Yesterday", conversations: 7, isActive: false
                            )
                            libraryCard(
                                name: "Mistral-7B-Instruct-v0.3", quant: "Q4_K_M", size: "4.1 GB",
                                tokSec: "~12 tok/s", isGreen: false,
                                lastUsed: "3 days ago", conversations: 3, isActive: false
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }

                downloadBar

                // Tab bar
                tabBar(selected: 1)
            }
        }
        .preferredColorScheme(.dark)
    }

    var libraryNavBar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Library")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DS.textPrimary)
                Spacer()
                Text("Edit")
                    .font(.system(size: 15))
                    .foregroundStyle(DS.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Rectangle().fill(DS.border).frame(height: 0.5)
        }
        .background(DS.cardBg.opacity(0.9))
    }

    var storageSummary: some View {
        HStack(spacing: 0) {
            Text("3 Models")
            Text("  ·  ").foregroundStyle(DS.textTertiary)
            Text("8.4 GB")
            Text("  ·  ").foregroundStyle(DS.textTertiary)
            Text("12.1 GB free")
        }
        .font(.system(size: 13, weight: .medium, design: .monospaced))
        .foregroundStyle(DS.textSecondary)
        .padding(.vertical, 10)
    }

    func libraryCard(
        name: String, quant: String, size: String,
        tokSec: String, isGreen: Bool,
        lastUsed: String, conversations: Int, isActive: Bool
    ) -> some View {
        HStack(spacing: 0) {
            if isActive {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(DS.accent)
                    .frame(width: 3)
                    .padding(.vertical, 8)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.textPrimary)
                            .lineLimit(1)
                        Text(quant)
                            .font(.system(size: 13))
                            .foregroundStyle(DS.textSecondary)
                    }
                    Spacer()
                    Text(tokSec)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isGreen ? DS.green : DS.amber)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background((isGreen ? DS.green : DS.amber).opacity(0.12))
                        .clipShape(Capsule())
                }

                HStack(spacing: 0) {
                    Text(size)
                        .font(.system(size: 12, design: .monospaced))
                    Text("  ·  ")
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 10))
                    Text(" \(conversations)")
                    Text("  ·  ")
                    Text(lastUsed)
                }
                .font(.system(size: 12))
                .foregroundStyle(DS.textTertiary)
            }
            .padding(.horizontal, isActive ? 13 : 16)
            .padding(.vertical, 14)
        }
        .background(DS.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    var downloadBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(DS.border).frame(height: 0.5)
            HStack(spacing: 12) {
                // Circular progress ring
                ZStack {
                    Circle().stroke(DS.border, lineWidth: 2.5).frame(width: 30, height: 30)
                    Circle()
                        .trim(from: 0, to: 0.63)
                        .stroke(DS.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 30, height: 30)
                        .rotationEffect(.degrees(-90))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("DeepSeek-R1-Distill-Qwen-7B")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 0) {
                        Text("63%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        Text("  ·  ")
                        Text("12.4 MB/s")
                            .font(.system(size: 11, design: .monospaced))
                        Text("  ·  ")
                        Text("~2 min left")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(DS.textSecondary)
                }

                Spacer()

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(DS.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(DS.cardBg.opacity(0.95))
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - MODEL LOADING STATE (Phase 4)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct LoadingScreen: View {
    var body: some View {
        ZStack {
            ModelRunnerGradient().ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Chat")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(DS.textPrimary)
                            Text("Qwen3-4B · Q4_K_M")
                                .font(.system(size: 12))
                                .foregroundStyle(DS.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    Rectangle().fill(DS.border).frame(height: 0.5)
                }
                .background(DS.cardBg.opacity(0.9))

                Spacer()

                VStack(spacing: 16) {
                    ZStack {
                        Circle().stroke(DS.border, lineWidth: 3).frame(width: 64, height: 64)
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(DS.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 64, height: 64)
                            .rotationEffect(.degrees(-90))
                    }
                    VStack(spacing: 4) {
                        Text("Loading Qwen3-4B Q4_K_M...")
                            .font(.system(size: 15))
                            .foregroundStyle(DS.textSecondary)
                        Text("2.5 GB into memory")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(DS.textTertiary)
                    }
                }

                Spacer()

                // Disabled input
                VStack(spacing: 0) {
                    Rectangle().fill(DS.border).frame(height: 0.5)
                    HStack(spacing: 12) {
                        HStack {
                            Text("Waiting for model...")
                                .font(.system(size: 15))
                                .foregroundStyle(DS.textTertiary.opacity(0.5))
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(DS.inputFieldBg.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        ZStack {
                            Circle().fill(DS.accent.opacity(0.2)).frame(width: 34, height: 34)
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(DS.textPrimary.opacity(0.2))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(DS.cardBg.opacity(0.95))
                }

                tabBar(selected: 2)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Shared Tab Bar
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func tabBar(selected: Int) -> some View {
    VStack(spacing: 0) {
        Rectangle().fill(DS.border).frame(height: 0.5)
        HStack {
            tabItem(icon: "square.grid.2x2", label: "Browse", isSelected: selected == 0)
            tabItem(icon: "tray.full", label: "Library", isSelected: selected == 1)
            tabItem(icon: "bubble.left.fill", label: "Chat", isSelected: selected == 2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(DS.cardBg.opacity(0.95))
    }
}

func tabItem(icon: String, label: String, isSelected: Bool) -> some View {
    VStack(spacing: 4) {
        Image(systemName: icon)
            .font(.system(size: 20))
        Text(label)
            .font(.system(size: 10, weight: .medium))
    }
    .foregroundStyle(isSelected ? DS.accent : DS.textTertiary)
    .frame(maxWidth: .infinity)
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Set Live View
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Change which screen to preview by swapping the line below:
//   ChatScreen()     — Chat with streaming response + stop button
//   LibraryScreen()  — Library tab with download bar + active model
//   LoadingScreen()  — Model loading state with progress ring

PlaygroundPage.current.setLiveView(
    ChatScreen()
        .frame(width: 390, height: 844)
)
