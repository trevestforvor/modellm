import SwiftUI

struct ChatLoadingView: View {
    let modelName: String
    let quantization: String
    let sizeDescription: String  // e.g. "3.8 GB"
    @State private var rotationAngle: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Track ring
                Circle()
                    .stroke(Color(hex: "#302E42"), lineWidth: 3)
                    .frame(width: 64, height: 64)
                // Spinning fill arc — 75% of circle, #4D6CF2 violet
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(
                        Color(hex: "#4D6CF2"),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear {
                        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                            rotationAngle = 360
                        }
                    }
            }

            Text("Loading \(modelName) \(quantization)...")
                .font(.figtree(.callout))
                .foregroundStyle(Color(hex: "#9896B0"))

            Text("\(sizeDescription) into memory")
                .font(.caption.monospaced())
                .foregroundStyle(Color(hex: "#6B6980"))
        }
    }
}
