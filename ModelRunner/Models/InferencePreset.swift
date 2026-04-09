import Foundation

enum InferencePreset: String, CaseIterable, Identifiable {
    case precise = "Precise"
    case balanced = "Balanced"
    case creative = "Creative"

    var id: String { rawValue }

    var temperature: Double {
        switch self {
        case .precise:  return 0.3
        case .balanced: return 0.7
        case .creative: return 1.2
        }
    }

    var topP: Double {
        switch self {
        case .precise:  return 0.7
        case .balanced: return 0.9
        case .creative: return 0.95
        }
    }

    /// Apply this preset's values to a DownloadedModel in SwiftData.
    func apply(to model: DownloadedModel) {
        model.temperature = temperature
        model.topP = topP
    }
}
