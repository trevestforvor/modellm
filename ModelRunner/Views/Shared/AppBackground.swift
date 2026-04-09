import SwiftUI

/// The app's signature MeshGradient background — dark spectrum with sapphire/violet/teal color flow.
/// Single source of truth. Used across all screens for visual consistency.
/// Colors match MeshGradientPreview.playground exactly.
struct AppBackground: View {
    var body: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                    SIMD2(0.0, 0.5), SIMD2(0.5, 0.5), SIMD2(1.0, 0.5),
                    SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
                ],
                colors: [
                    // Top row: sapphire -> dark base -> teal
                    Color(hex: "#172440"), Color(hex: "#0F0E1A"), Color(hex: "#122A32"),
                    // Middle row: violet -> dark base -> deep blue
                    Color(hex: "#221942"), Color(hex: "#110F1C"), Color(hex: "#141E3A"),
                    // Bottom row: dark base -> teal-blue -> violet
                    Color(hex: "#0F0E1A"), Color(hex: "#12242C"), Color(hex: "#1C153E")
                ]
            )
            .ignoresSafeArea()
        } else {
            Color(hex: "#0F0E1A")
                .ignoresSafeArea()
        }
    }
}
