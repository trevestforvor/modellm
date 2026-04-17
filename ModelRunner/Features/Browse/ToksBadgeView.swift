import SwiftUI

/// The tok/s compatibility badge — centerpiece of every model card and variant row.
/// Shows only for .runsWell and .runsSlowly tiers. Never instantiate for .incompatible.
struct ToksBadgeView: View {

    let result: CompatibilityResult

    private var badgeColor: Color {
        switch result.tier {
        case .runsWell:  return Color(hex: "#34D399")
        case .runsSlow:  return Color(hex: "#FBBF24")
        case .incompatible: return .clear
        }
    }

    private var badgeText: String {
        switch result {
        case .runsWell(let range):
            let mid = Int((range.lowerBound + range.upperBound) / 2)
            return "~\(mid) tok/s"
        case .runsSlowly(let range, _):
            let mid = Int((range.lowerBound + range.upperBound) / 2)
            return "~\(mid) tok/s"
        case .incompatible:
            return ""
        }
    }

    private var accessibilityN: Int {
        switch result {
        case .runsWell(let range):      return Int((range.lowerBound + range.upperBound) / 2)
        case .runsSlowly(let range, _): return Int((range.lowerBound + range.upperBound) / 2)
        case .incompatible:             return 0
        }
    }

    var body: some View {
        if result.tier != .incompatible {
            Text(badgeText)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(badgeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(badgeColor.opacity(0.12))
                )
                .accessibilityLabel("Runs at approximately \(accessibilityN) tokens per second")
        }
    }
}

// MARK: - Color(hex:) Extension

extension Color {
    /// Initializes a Color from a hex string like "#34D399" or "34D399".
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

#Preview {
    VStack(spacing: 16) {
        ToksBadgeView(result: .runsWell(estimatedTokensPerSec: 20...30))
        ToksBadgeView(result: .runsSlowly(estimatedTokensPerSec: 5...10, warning: "Slow on this device"))
    }
    .padding()
    .background(Color(hex: "#0D0C18"))
}
