import SwiftUI

/// The app's signature MeshGradient background. Vibrant indigo/violet up top,
/// compressed near-black at the bottom so the input bar and chrome blend into it.
/// The middle row is nudged downward (0.58) to give the top more visual weight.
/// A RadialGradient overlay adds a soft indigo glow in the top-leading corner.
struct AppBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                    SIMD2(0.0, 0.58), SIMD2(0.5, 0.58), SIMD2(1.0, 0.58),
                    SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
                ],
                colors: [
                    // Top row (vibrant but still controlled)
                    Color(hex: "#1E2A78"),  // deep indigo-blue
                    Color(hex: "#2B2180"),  // toned-down violet (was #3A2DA8)
                    Color(hex: "#1C3F7A"),  // blue push

                    // Middle row (blend zone)
                    Color(hex: "#1A1F4D"),
                    Color(hex: "#221B5C"),
                    Color(hex: "#162A52"),

                    // Bottom row (intentionally compressed / dark)
                    Color(hex: "#0B0C1A"),
                    Color(hex: "#080913"),
                    Color(hex: "#0A0E1F")
                ]
            )
            .overlay {
                // Drop the radial glow for users with Reduce Motion enabled —
                // blend modes can cause visual shimmer on some devices and the glow
                // reads as "ambient light" which Reduce Motion prefers to minimize.
                if !reduceMotion {
                    RadialGradient(
                        colors: [
                            Color(hex: "#6C5CFF").opacity(0.10),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 500
                    )
                    .blendMode(.plusLighter)
                }
            }
            .ignoresSafeArea()
        } else {
            Color(hex: "#0D0C18")
                .ignoresSafeArea()
        }
    }
}
