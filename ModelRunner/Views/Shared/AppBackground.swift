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
                    // Top row — subtle indigo tint, far darker than v1 per Cinema Mobile spec.
                    // Luminance roughly matches #0A0A0F base; color barely above monochrome.
                    Color(hex: "#141830"),  // deep indigo
                    Color(hex: "#0D0E1E"),  // near-base neutral
                    Color(hex: "#12182C"),  // subtle sapphire

                    // Middle row — even darker blend zone
                    Color(hex: "#0B0D1C"),
                    Color(hex: "#070812"),
                    Color(hex: "#090E1C"),

                    // Bottom row — approaches #020203 per spec; cards on top read clean
                    Color(hex: "#030308"),
                    Color(hex: "#020203"),
                    Color(hex: "#03050E")
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
