import SwiftUI

// MARK: - Design System Card Surface
//
// Shared card styling. Apply via `.appCard()` or wrap content in the
// `AppCardBackground` view. All cards across Browse, Models, Library, and
// Detail share this treatment so surfaces stay consistent.

struct AppCardBackground: View {
    var cornerRadius: CGFloat = 14
    var isSelected: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.appAccent : Color.appBorder,
                                  lineWidth: isSelected ? 1.5 : 1)
            )
    }
}

private struct AppCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 14
    var padding: CGFloat = 14
    var isSelected: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppCardBackground(cornerRadius: cornerRadius, isSelected: isSelected))
    }
}

extension View {
    /// Applies the app-wide card surface (fill + border + corner radius) with default padding.
    func appCard(cornerRadius: CGFloat = 14, padding: CGFloat = 14, isSelected: Bool = false) -> some View {
        modifier(AppCardModifier(cornerRadius: cornerRadius, padding: padding, isSelected: isSelected))
    }
}
