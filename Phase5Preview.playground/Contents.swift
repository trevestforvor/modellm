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
    static let glassBg = Color(hex: 0x1A1830, opacity: 0.6)
    static let glassBorder = Color(hex: 0x302E42)
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
// MARK: - CHAT TAB (unified: active chat + history overlay)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// Preview state: showHistory = false → active chat with history button
//                showHistory = true  → history overlay covering chat

struct ChatWithHistoryScreen: View {
    @State private var showHistory = false

    var body: some View {
        ZStack {
            ModelRunnerGradient().ignoresSafeArea()

            VStack(spacing: 0) {
                chatNavBar

                // Active chat content (visible when history is hidden)
                if !showHistory {
                    activeChatContent
                }

                // History overlay grows upward from above the input bar
                if showHistory {
                    historyOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Input bar with history toggle (always at bottom)
                chatInputBar

                tabBar(selected: 2)
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

    // MARK: Active Chat Content

    var activeChatContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Sample conversation
                userBubble("What's the best way to learn SwiftUI?")

                assistantBubble("Start with Apple's official tutorials at developer.apple.com. They walk you through building real apps step by step.\n\nThen pick a small project you actually want to build. The best way to learn SwiftUI is by using it for something you care about.")

                userBubble("Any good YouTube channels?")

                assistantBubble("A few solid ones:\n\n• Sean Allen — practical tutorials, interview prep\n• Paul Hudson (Hacking with Swift) — comprehensive, beginner-friendly\n• Stewart Lynch — focused on specific SwiftUI patterns\n• Kavsoft — beautiful UI recreation tutorials")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: History Overlay

    var historyOverlay: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Spacer pushes content to the bottom
                Spacer(minLength: 0)
                    .frame(maxHeight: .infinity)

                // Header
                HStack {
                    Text("History")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.textSecondary)
                    Spacer()
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            showHistory = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DS.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                // Model group: Gemma-3-3B (older, further up)
                historyModelGroup(
                    name: "Gemma-3-3B",
                    quant: "Q4_K_M",
                    tokSec: "~38 tok/s",
                    isGreen: true,
                    conversations: [
                        ("What's the best way to learn SwiftUI?", "4 days ago"),
                        ("Write a short story about a robot gardener", "Yesterday"),
                    ]
                )

                // Model group: Qwen3-4B (most recent, closest to input)
                historyModelGroup(
                    name: "Qwen3-4B",
                    quant: "Q4_K_M",
                    tokSec: "~32 tok/s",
                    isGreen: true,
                    conversations: [
                        ("Explain quantum computing in simple terms", "3 days ago"),
                        ("Help me write a Python script that parses CSV...", "Yesterday"),
                        ("What's the best way to learn SwiftUI?", "2 hours ago"),
                    ]
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .frame(minHeight: 400)
        }
        .defaultScrollAnchor(.bottom)
    }

    func historyModelGroup(name: String, quant: String, tokSec: String, isGreen: Bool, conversations: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.textPrimary)
                Text(quant)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.textTertiary)
                Spacer()
                Text(tokSec)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isGreen ? DS.green : DS.amber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((isGreen ? DS.green : DS.amber).opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(spacing: 6) {
                ForEach(Array(conversations.enumerated()), id: \.offset) { _, conv in
                    historyRow(title: conv.0, time: conv.1)
                }
            }
        }
    }

    func historyRow(title: String, time: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(DS.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(time)
                .font(.system(size: 12))
                .foregroundStyle(DS.textTertiary)
                .layoutPriority(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(DS.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DS.glassBorder, lineWidth: 0.5)
        )
    }

    // MARK: Bubbles (for active chat preview)

    func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 60)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(DS.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(DS.accent)
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

    func assistantBubble(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(DS.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(hex: 0x1A1830))
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: 4,
                        bottomTrailingRadius: 16,
                        topTrailingRadius: 16
                    )
                )
            Spacer(minLength: 60)
        }
    }

    // MARK: Input Bar with History Toggle

    var chatInputBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(DS.border).frame(height: 0.5)
            HStack(spacing: 10) {
                // History toggle button (glass)
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        showHistory.toggle()
                    }
                } label: {
                    Image(systemName: showHistory ? "clock.fill" : "clock")
                        .font(.system(size: 16))
                        .foregroundStyle(showHistory ? DS.accent : DS.textTertiary)
                        .frame(width: 34, height: 34)
                        .background(DS.glassBg)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DS.glassBorder, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)

                // Text field
                HStack {
                    Text("Message...")
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

                // Send button
                ZStack {
                    Circle().fill(DS.accent.opacity(0.4)).frame(width: 34, height: 34)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DS.textPrimary.opacity(0.4))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(DS.cardBg.opacity(0.95))
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - PARAMETER SETTINGS VIEW
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct SettingsScreen: View {
    @State private var selectedPreset = 1 // 0=Precise, 1=Balanced, 2=Creative
    @State private var temperature: Double = 0.7
    @State private var topP: Double = 0.9
    @State private var showAdvanced = false

    var body: some View {
        ZStack {
            ModelRunnerGradient().ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.accent)
                        Text("Chat Settings")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(DS.textPrimary)
                        Spacer()
                        Text("Qwen3-4B")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    Rectangle().fill(DS.border).frame(height: 0.5)
                }
                .background(DS.cardBg.opacity(0.9))

                ScrollView {
                    VStack(spacing: 16) {
                        // Style presets section
                        settingsSection("Style") {
                            HStack(spacing: 8) {
                                presetPill("Precise", index: 0)
                                presetPill("Balanced", index: 1)
                                presetPill("Creative", index: 2)
                            }
                        }

                        // Advanced section (expandable)
                        settingsSection("Advanced") {
                            VStack(spacing: 16) {
                                // Disclosure toggle
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showAdvanced.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Text("Show sliders")
                                            .font(.system(size: 15))
                                            .foregroundStyle(DS.textSecondary)
                                        Spacer()
                                        Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(DS.textTertiary)
                                    }
                                }
                                .buttonStyle(.plain)

                                if showAdvanced {
                                    // Temperature slider
                                    VStack(spacing: 6) {
                                        HStack {
                                            Text("Temperature")
                                                .font(.system(size: 14))
                                                .foregroundStyle(DS.textSecondary)
                                            Spacer()
                                            Text(String(format: "%.1f", temperature))
                                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(DS.textPrimary)
                                        }
                                        Slider(value: $temperature, in: 0...2, step: 0.1)
                                            .tint(DS.accent)
                                        HStack {
                                            Text("Precise")
                                                .font(.system(size: 11))
                                            Spacer()
                                            Text("Creative")
                                                .font(.system(size: 11))
                                        }
                                        .foregroundStyle(DS.textTertiary)
                                    }

                                    // Top-p slider
                                    VStack(spacing: 6) {
                                        HStack {
                                            Text("Top-p")
                                                .font(.system(size: 14))
                                                .foregroundStyle(DS.textSecondary)
                                            Spacer()
                                            Text(String(format: "%.2f", topP))
                                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(DS.textPrimary)
                                        }
                                        Slider(value: $topP, in: 0...1, step: 0.05)
                                            .tint(DS.accent)
                                        HStack {
                                            Text("Focused")
                                                .font(.system(size: 11))
                                            Spacer()
                                            Text("Diverse")
                                                .font(.system(size: 11))
                                        }
                                        .foregroundStyle(DS.textTertiary)
                                    }
                                }
                            }
                        }

                        // System Prompt section
                        settingsSection("System Prompt") {
                            VStack(spacing: 10) {
                                // Preset chips
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        promptChip("Helpful assistant")
                                        promptChip("Creative writer")
                                        promptChip("Code helper")
                                        promptChip("Tutor")
                                    }
                                }

                                // Text field
                                VStack(alignment: .leading) {
                                    Text("You are a helpful assistant. Answer questions clearly and concisely.")
                                        .font(.system(size: 14))
                                        .foregroundStyle(DS.textPrimary)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                                }
                                .background(Color(hex: 0x1A1830, opacity: 0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(DS.border, lineWidth: 0.5)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.textTertiary)
                .tracking(0.8)

            VStack(spacing: 0) {
                content()
            }
            .padding(14)
            .background(DS.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DS.glassBorder, lineWidth: 0.5)
            )
        }
    }

    func presetPill(_ label: String, index: Int) -> some View {
        Button {
            selectedPreset = index
            switch index {
            case 0: temperature = 0.3; topP = 0.8
            case 1: temperature = 0.7; topP = 0.9
            case 2: temperature = 1.2; topP = 0.95
            default: break
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(selectedPreset == index ? DS.textPrimary : DS.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(selectedPreset == index ? DS.accent : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(selectedPreset == index ? Color.clear : DS.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    func promptChip(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(DS.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(DS.border, lineWidth: 0.5)
            )
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - WELCOME SCREEN (first launch)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct WelcomeScreen: View {
    var body: some View {
        ZStack {
            ModelRunnerGradient().ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                Spacer()

                // App identity
                VStack(spacing: 12) {
                    // App icon placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(DS.accent.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "cpu")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(DS.accent)
                    }

                    Text("ModelRunner")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(DS.textPrimary)
                }

                Spacer()
                    .frame(height: 24)

                // Tagline
                VStack(spacing: 8) {
                    Text("Run AI on your iPhone")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)

                    Text("Browse compatible models, download,\nand chat — all on device.")
                        .font(.system(size: 15))
                        .foregroundStyle(DS.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }

                Spacer()
                Spacer()

                // Action buttons
                VStack(spacing: 10) {
                    // Primary: Show Me Around (guided)
                    Button {} label: {
                        Text("Show Me Around")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DS.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    // Secondary: Get Started (skip)
                    Button {} label: {
                        Text("Get Started")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DS.glassBg)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(DS.glassBorder, lineWidth: 0.5)
                                )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
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
//   ChatWithHistoryScreen()  — Chat tab with history overlay toggle (tap clock icon)
//   SettingsScreen()         — Parameter settings with presets + sliders
//   WelcomeScreen()          — First launch welcome with two paths

PlaygroundPage.current.setLiveView(
    ChatWithHistoryScreen()
        .frame(width: 390, height: 844)
)
