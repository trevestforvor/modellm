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
                    // Top row — +15% blue, +10% brightness over the previous pass.
                    // Still restrained but visibly lifted so the gradient doesn't crush into pure black.
                    Color(hex: "#161A3C"),  // deep indigo
                    Color(hex: "#0E0F27"),  // near-base neutral
                    Color(hex: "#141A38"),  // subtle sapphire

                    // Middle row — +15% blue shift only, brightness unchanged
                    Color(hex: "#0B0D20"),
                    Color(hex: "#070815"),
                    Color(hex: "#090E20"),

                    // Bottom row — +15% blue + ~5% brightness lift off pure black
                    Color(hex: "#07070D"),
                    Color(hex: "#060607"),
                    Color(hex: "#070915")
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
