import UIKit

/// Applies the app's custom fonts (Outfit / Figtree) to UIKit surfaces that
/// SwiftUI doesn't expose direct font control over — navigation bar titles,
/// large titles, and bar button items (Done / Back text).
///
/// Call `AppAppearance.configure()` once at app launch.
enum AppAppearance {
    static func configure() {
        configureNavigationBar()
        configureBarButtons()
    }

    private static func configureNavigationBar() {
        let titleFont = outfitFont(size: 17, weight: .semibold)
        let largeTitleFont = outfitFont(size: 34, weight: .bold)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.titleTextAttributes = [
            .font: titleFont,
            .foregroundColor: UIColor.white
        ]
        appearance.largeTitleTextAttributes = [
            .font: largeTitleFont,
            .foregroundColor: UIColor.white
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    private static func configureBarButtons() {
        // SwiftUI's `Button("...")` inside `.toolbar { ToolbarItem { ... } }` is rendered
        // by SwiftUI — it bypasses both the global UIBarButtonItem proxy AND the
        // navigation bar's buttonAppearance entirely. Fonts on those buttons must be
        // applied at the call site via `Text("Done").font(.figtree(.body, weight: .medium))`.
        // This function is intentionally a no-op; kept so the init flow reads consistently.
    }

    // MARK: - Variable-font weight helpers

    /// Returns Outfit at the requested weight. Variable fonts expose weight via
    /// a font descriptor trait — UIFont(name:size:) alone gives you the default
    /// (regular), so we build a descriptor with the weight trait applied.
    private static func outfitFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        customFont(familyName: "Outfit", size: size, weight: weight)
    }

    private static func figtreeFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        customFont(familyName: "Figtree", size: size, weight: weight)
    }

    private static func customFont(familyName: String, size: CGFloat, weight: UIFont.Weight) -> UIFont {
        // Fall back to the system font at the same weight if the custom font isn't
        // registered (e.g., Info.plist mis-config) — avoids a hard crash.
        guard let base = UIFont(name: familyName, size: size) else {
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
        let descriptor = base.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight.rawValue]
        ])
        return UIFont(descriptor: descriptor, size: size)
    }
}
