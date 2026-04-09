import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isGenerating: Bool
    let isModelLoaded: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isModelLoaded && !isGenerating
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField(isModelLoaded ? "Message..." : "Waiting for model...", text: $text, axis: .vertical)
                .lineLimit(1...6)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#1A1830"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color(hex: "#302E42"), lineWidth: 0.5)
                        )
                )
                .foregroundStyle(.white)
                .font(.system(size: 15))
                .disabled(!isModelLoaded)
                .opacity(isModelLoaded ? 1 : 0.5)
                .onSubmit {
                    if canSend { onSend() }
                }

            actionButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color(hex: "#0D0C18").opacity(0.95)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(hex: "#302E42"))
                        .frame(height: 0.5)
                }
        )
    }

    private var actionButton: some View {
        Button {
            if isGenerating {
                onStop()
            } else if canSend {
                onSend()
                text = ""
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isGenerating ? Color(hex: "#FBBF24") : Color(hex: "#8B7CF0").opacity(canSend ? 1 : 0.4))
                    .frame(width: 34, height: 34)

                Image(systemName: isGenerating ? "stop.fill" : "arrow.up")
                    .font(.system(size: isGenerating ? 12 : 14, weight: .bold))
                    .foregroundStyle(isGenerating ? .black : .white)
            }
        }
        .disabled(!isGenerating && !canSend)
        .animation(.easeInOut(duration: 0.15), value: isGenerating)
    }
}
