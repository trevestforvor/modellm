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
                // Spinning fill arc — 75% of circle, #8B7CF0 violet
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(
                        Color(hex: "#8B7CF0"),
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
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "#9896B0"))

            Text("\(sizeDescription) into memory")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color(hex: "#6B6980"))
        }
    }
}
