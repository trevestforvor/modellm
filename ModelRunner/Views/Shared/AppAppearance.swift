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
        // For variable fonts (Outfit, Figtree), expose weight via the CoreText `wght`
        // variation axis. UIFontDescriptor's `.traits[.weight:]` doesn't propagate to
        // variable fonts — the font still renders at its default weight. The `wght`
        // axis uses standard CSS-style numeric values (400 = regular, 600 = semibold,
        // 700 = bold). FourCharCode('wght') = 2003265652.
        let wghtTag = 2003265652
        let wghtValue = cssWeight(for: weight)
        let descriptor = base.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: "NSCTFontVariationAttribute"): [wghtTag: wghtValue]
        ])
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Map UIFont.Weight into a CSS-style `wght` axis value used by variable fonts.
    private static func cssWeight(for weight: UIFont.Weight) -> Int {
        switch weight {
        case .ultraLight: return 100
        case .thin:       return 200
        case .light:      return 300
        case .regular:    return 400
        case .medium:     return 500
        case .semibold:   return 600
        case .bold:       return 700
        case .heavy:      return 800
        case .black:      return 900
        default:          return 400
        }
    }
}
