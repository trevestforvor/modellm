import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isGenerating: Bool
    let isModelLoaded: Bool
    let onSend: () -> Void
    let onStop: () -> Void
    /// Reserved for capability gating of attach actions themselves (not the button).
    /// The `+` menu is always shown; vision-only actions are selectively enabled/disabled.
    var supportsVision: Bool = false
    var onAttachFile: () -> Void = {}
    var onTakePhoto: () -> Void = {}
    var onAttachPhoto: () -> Void = {}
    @Binding var enableThinking: Bool

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isModelLoaded && !isGenerating
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            AttachmentMenu(
                supportsVision: supportsVision,
                onAttachFile: onAttachFile,
                onTakePhoto: onTakePhoto,
                onAttachPhoto: onAttachPhoto
            )

            // Brain button — toggles thinking/reasoning mode
            Button {
                enableThinking.toggle()
            } label: {
                Image(systemName: "brain")
                    .font(.iconLG)
                    .foregroundStyle(enableThinking ? Color(hex: "#4D6CF2") : Color(hex: "#6B6980"))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(enableThinking ? Color(hex: "#4D6CF2").opacity(0.15) : Color(hex: "#1A1830").opacity(0.6))
                            .overlay(Circle().strokeBorder(
                                enableThinking ? Color(hex: "#4D6CF2").opacity(0.3) : Color.white.opacity(0.08),
                                lineWidth: 0.5
                            ))
                    )
            }
            .buttonStyle(.pressScale)
            .accessibilityLabel("Toggle thinking mode")
            .accessibilityHint("When on, the model shows its reasoning before the final answer")

            TextField(isModelLoaded ? "Message..." : "Waiting for model...", text: $text, axis: .vertical)
                .lineLimit(1...6)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#1A1830"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                )
                .foregroundStyle(.white)
                .font(.appBody)
                .disabled(!isModelLoaded)
                .opacity(isModelLoaded ? 1 : 0.5)
                .onSubmit {
                    if canSend { onSend() }
                }

            actionButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(alignment: .top) {
            Rectangle()
                .fill(Color(hex: "#302E42"))
                .frame(height: 0.5)
        }
        .background(
            Color(hex: "#0D0C18")
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var actionButton: some View {
        Button {
            if isGenerating {
                Haptics.medium()
                onStop()
            } else if canSend {
                Haptics.light()
                onSend()
                text = ""
            }
        } label: {
            ZStack {
                // Same accent hue for send and stop — the icon (arrow vs square) carries
                // the semantic, opacity differentiates state without introducing a new color.
                Circle()
                    .fill(Color(hex: "#4D6CF2").opacity(isGenerating ? 0.55 : (canSend ? 1 : 0.4)))
                    .frame(width: 34, height: 34)

                Image(systemName: isGenerating ? "stop.fill" : "arrow.up")
                    .font(.iconMD)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.pressScale)
        .disabled(!isGenerating && !canSend)
        .animation(.easeInOut(duration: 0.15), value: isGenerating)
        .accessibilityLabel(isGenerating ? "Stop generating" : "Send message")
    }
}
