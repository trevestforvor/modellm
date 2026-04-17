import SwiftUI

/// Typography helpers for the app's bundled font system:
/// - Outfit for headers/titles/hero text
/// - Figtree for body / UI / secondary text
/// - SF Mono (Apple-shipped) stays for technical metadata — use `.monospaced()`
///
/// All helpers map to semantic TextStyles so Dynamic Type still scales.
extension Font {
    static func outfit(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .custom("Outfit", size: style.pointSize, relativeTo: style).weight(weight)
    }

    static func figtree(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .custom("Figtree", size: style.pointSize, relativeTo: style).weight(weight)
    }

    // MARK: Semantic tokens

    static let appTitle: Font         = outfit(.title3, weight: .semibold)
    static let appHeadline: Font      = outfit(.headline, weight: .semibold)
    static let appBody: Font          = figtree(.body)
    static let appBodyEmphasized: Font = figtree(.body, weight: .medium)
    static let appSubheadline: Font   = figtree(.subheadline)
    static let appCaption: Font       = figtree(.caption)
    static let appMono: Font          = Font.system(.body, design: .monospaced)
    static let appMonoSmall: Font     = Font.system(.caption, design: .monospaced)

    // MARK: Icon sizes (used with Image systemName)

    static let iconXL: Font = .system(size: 28)
    static let iconLG: Font = .system(size: 22)
    static let iconMD: Font = .system(size: 18)
}

private extension Font.TextStyle {
    /// Point size aligned with the iOS default type scale at non-accessibility sizes.
    /// Used as the base for `relativeTo:` so Dynamic Type still scales our custom fonts.
    var pointSize: CGFloat {
        switch self {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        default: return 17
        }
    }
}
