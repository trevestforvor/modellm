import SwiftUI

// MARK: - Design System Palette
//
// Single source of truth for colors across the app. Mirrors the structure of AppFont.
//
// Rules:
//   1. All fills/strokes/text colors use one of the `appX` tokens below.
//   2. No raw `Color(hex:)` literals in feature code — add a token here first.
//   3. No `.secondary` / `.tertiary` system semantic colors for dark-theme surfaces;
//      those resolve against system appearance and break the palette.
//   4. No `.regularMaterial` / `.ultraThinMaterial` for cards — those are frosted and
//      light-biased in a dark theme.

extension Color {

    // MARK: Surfaces

    /// App-wide page background (under AppBackground mesh). #0D0C18
    static let appPage: Color = Color(hex: "#0D0C18")

    /// Elevated surface for cards, list rows, grouped sections. #1A1830
    static let appSurface: Color = Color(hex: "#1A1830")

    /// 1pt border/divider on surfaces. #302E42
    static let appBorder: Color = Color(hex: "#302E42")

    // MARK: Text

    /// Primary text on surfaces. #EDEDF4
    static let appTextPrimary: Color = Color(hex: "#EDEDF4")

    /// Secondary metadata text. #9896B0
    static let appTextSecondary: Color = Color(hex: "#9896B0")

    /// Tertiary / most de-emphasized text. #6B6980
    static let appTextTertiary: Color = Color(hex: "#6B6980")

    // MARK: Semantic

    /// Primary accent (interactive, download, selection). #4D6CF2
    static let appAccent: Color = Color(hex: "#4D6CF2")

    /// Positive signal — runs well, online, success. #34D399
    static let appGood: Color = Color(hex: "#34D399")

    /// Caution signal — runs slow, warnings. #FBBF24
    static let appWarn: Color = Color(hex: "#FBBF24")
}
