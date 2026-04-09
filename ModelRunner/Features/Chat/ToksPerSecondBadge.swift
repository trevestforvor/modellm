import SwiftUI

/// Tok/s display shown below assistant bubbles during and after inference.
/// Green during generation, fades to tertiary 2 seconds after completion.
struct ToksPerSecondBadge: View {
    let tokensPerSecond: Double
    let isGenerating: Bool

    private var text: String {
        tokensPerSecond > 0 ? String(format: "%.1f tok/s", tokensPerSecond) : ""
    }

    private var color: Color {
        isGenerating ? Color(hex: "#34D399") : Color(hex: "#6B6980")
    }

    var body: some View {
        if tokensPerSecond > 0 {
            Text(text)
                .font(.system(.caption2, design: .monospaced))  // SF Mono 11pt equivalent
                .foregroundStyle(color)
                .animation(.easeOut(duration: 0.5), value: isGenerating)
        }
    }
}
