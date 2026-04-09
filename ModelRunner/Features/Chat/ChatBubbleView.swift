import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let tokensPerSecond: Double
    let isGenerating: Bool

    // Asymmetric corner radius: 4pt on tail corner, 16pt elsewhere
    private var userCornerRadii: RectangleCornerRadii {
        RectangleCornerRadii(
            topLeading: 16, bottomLeading: 16,
            bottomTrailing: 4,  // tail corner
            topTrailing: 16
        )
    }

    private var assistantCornerRadii: RectangleCornerRadii {
        RectangleCornerRadii(
            topLeading: 16,
            bottomLeading: 4,  // tail corner
            bottomTrailing: 16, topTrailing: 16
        )
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 60)
                userBubble
            } else {
                assistantBubble
                Spacer(minLength: 60)
            }
        }
    }

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
        VStack(alignment: .leading, spacing: 4) {
            assistantContent
            if message.role == .assistant && (isGenerating || tokensPerSecond > 0) {
                ToksPerSecondBadge(tokensPerSecond: tokensPerSecond, isGenerating: isGenerating)
                    .padding(.leading, 12)
            }
        }
    }

    private var assistantContent: some View {
        Group {
            // For streaming messages: show content + blinking violet cursor
            if message.isStreaming {
                (Text(message.content) + Text("▋").foregroundStyle(Color(hex: "#8B7CF0")))
                    .font(.body)
            } else {
                // Render markdown for completed messages
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
