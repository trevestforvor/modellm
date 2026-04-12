import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let tokensPerSecond: Double
    let isGenerating: Bool

    @State private var isThinkingExpanded: Bool = false

    private var userCornerRadii: RectangleCornerRadii {
        RectangleCornerRadii(topLeading: 16, bottomLeading: 16, bottomTrailing: 4, topTrailing: 16)
    }

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
                            .padding(.leading, 12)
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
                            .font(.system(size: 13, weight: .medium))
                    } else if let duration = message.thinkingDuration {
                        Text("Thought for \(String(format: "%.1f", duration))s")
                            .font(.system(size: 13, weight: .medium))
                    } else {
                        Text("Thinking")
                            .font(.system(size: 13, weight: .medium))
                    }
                    Spacer()
                    Image(systemName: isThinkingExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundStyle(Color(hex: "#6B6980"))
            }

            if isThinkingExpanded || message.isStreaming {
                Text(message.thinkingContent)
                    .font(.system(size: 13))
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
                UnevenRoundedRectangle(cornerRadii: userCornerRadii)
                    .fill(Color(hex: "#8B7CF0"))
            )
            .foregroundStyle(.white)
            .font(.body)
    }

    private var assistantBubble: some View {
        assistantContent
    }

    private var assistantContent: some View {
        Group {
            if message.isStreaming {
                (Text(message.content) + Text("\u{258B}").foregroundStyle(Color(hex: "#8B7CF0")))
                    .font(.body)
            } else {
                markdownContent(message.content)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            UnevenRoundedRectangle(cornerRadii: assistantCornerRadii)
                .fill(Color(hex: "#1A1830"))
        )
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func markdownContent(_ text: String) -> some View {
        if let attributed = try? AttributedString(markdown: text) {
            Text(attributed)
                .font(.body)
        } else {
            Text(text)
                .font(.body)
        }
    }
}
