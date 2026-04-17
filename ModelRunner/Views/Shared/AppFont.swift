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
