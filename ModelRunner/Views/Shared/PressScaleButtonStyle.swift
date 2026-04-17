import SwiftUI

/// ButtonStyle that scales the label down on press with a quick spring.
/// Adopted from the "Modern Dark (Cinema Mobile)" UX pattern. Pair with
/// a haptic in the button's action closure for full press feedback.
/// Respects `accessibilityReduceMotion` — when enabled, press-scale is disabled
/// so the button stays rock-still (users preferring reduced motion don't want
/// cards visibly contracting on every tap).
struct PressScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        PressScaleContent(configuration: configuration, pressedScale: pressedScale)
    }

    private struct PressScaleContent: View {
        let configuration: Configuration
        let pressedScale: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !reduceMotion ? pressedScale : 1.0)
                .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.6),
                           value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == PressScaleButtonStyle {
    static var pressScale: PressScaleButtonStyle { PressScaleButtonStyle() }
}
