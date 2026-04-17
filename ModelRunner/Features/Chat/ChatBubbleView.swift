import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let tokensPerSecond: Double
    let isGenerating: Bool
    var onFeedback: (String) -> Void = { _ in }
    var onCopy: () -> Void = {}
    var onRegenerate: () -> Void = {}

    @State private var isThinkingExpanded: Bool = false
    @State private var copyFlashActive: Bool = false

    private var assistantCornerRadii: RectangleCornerRadii {
        RectangleCornerRadii(topLeading: 16, bottomLeading: 4, bottomTrailing: 16, topTrailing: 16)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 60)
                userBubble
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    if !message.thinkingContent.isEmpty {
                        thinkingBlock
                    }
                    assistantBubble
                    if message.role == .assistant && (isGenerating || tokensPerSecond > 0) {
                        ToksPerSecondBadge(tokensPerSecond: tokensPerSecond, isGenerating: isGenerating)
                            .padding(.leading, 16)
                    }
                    if message.role == .assistant && !message.isStreaming && !isGenerating {
                        feedbackRow
                    }
                }
                Spacer(minLength: 60)
            }
        }
    }

    // MARK: - Thinking Block

    private var thinkingBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isThinkingExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
                        .font(.system(size: 12))
                    if isThinkingExpanded || message.isStreaming {
                        Text("Thinking")
                            .font(.footnote.weight(.medium))
                    } else if let duration = message.thinkingDuration {
                        Text("Thought for \(String(format: "%.1f", duration))s")
                            .font(.footnote.weight(.medium))
                    } else {
                        Text("Thinking")
                            .font(.footnote.weight(.medium))
                    }
                    Spacer()
                    Image(systemName: isThinkingExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundStyle(Color(hex: "#6B6980"))
            }

            if isThinkingExpanded || message.isStreaming {
                Text(message.thinkingContent)
                    .font(.footnote)
                    .foregroundStyle(Color(hex: "#6B6980"))
                    .italic()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            UnevenRoundedRectangle(cornerRadii: assistantCornerRadii)
                .fill(Color(hex: "#13111F"))
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: assistantCornerRadii)
                        .strokeBorder(Color(hex: "#1E1C30"), lineWidth: 0.5)
                )
        )
        .onChange(of: message.isStreaming) { wasStreaming, isNowStreaming in
            if wasStreaming && !isNowStreaming {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isThinkingExpanded = false
                }
            }
        }
    }

    // MARK: - Bubbles

    private var userBubble: some View {
        Text(message.content)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#4D6CF2"))
            )
            .foregroundStyle(.white)
            .font(.body)
    }

    private var assistantBubble: some View {
        assistantContent
    }

    private var assistantContent: some View {
        markdownText(message.content)
            .font(.body)
            .lineSpacing(3)
            .foregroundStyle(Color(hex: "#EDEDF4"))
            .padding(.horizontal, 16)
            .accessibilityAddTraits(message.isStreaming ? [.updatesFrequently] : [])
    }

    // MARK: - Feedback Row

    private var feedbackRow: some View {
        HStack(spacing: 16) {
            feedbackIcon(system: message.feedback == "up" ? "hand.thumbsup.fill" : "hand.thumbsup",
                         active: message.feedback == "up",
                         label: "Good response") {
                onFeedback("up")
            }
            feedbackIcon(system: message.feedback == "down" ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                         active: message.feedback == "down",
                         label: "Bad response") {
                onFeedback("down")
            }
            feedbackIcon(system: "doc.on.doc",
                         active: copyFlashActive,
                         label: "Copy message",
                         flashColor: Color(hex: "#34D399")) {
                onCopy()
                copyFlashActive = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    copyFlashActive = false
                }
            }
            feedbackIcon(system: "arrow.counterclockwise",
                         active: false,
                         label: "Regenerate response") {
                onRegenerate()
            }
        }
        .padding(.leading, 16)
        .padding(.top, 2)
    }

    private func feedbackIcon(system: String,
                              active: Bool,
                              label: String,
                              flashColor: Color? = nil,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(active ? (flashColor ?? Color(hex: "#4D6CF2")) : Color(hex: "#6B6980"))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressScale)
        .accessibilityLabel(label)
    }

    /// Render markdown safely — falls back to plain text if markdown is malformed
    /// (e.g., unclosed ** or ` during streaming). LocalizedStringKey silently
    /// truncates on broken markdown, which causes responses to appear cut off.
    @ViewBuilder
    private func markdownText(_ text: String) -> some View {
        if message.isStreaming {
            // During streaming, markdown is likely incomplete — show plain text
            Text(text)
        } else if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
        } else {
            // Markdown parse failed — show plain text
            Text(text)
        }
    }
}
