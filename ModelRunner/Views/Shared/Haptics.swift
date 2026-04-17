import UIKit

/// Convenience wrappers for UIImpactFeedbackGenerator. Prepare + fire pattern
/// eliminates the ~100ms delay on first trigger. For UI use from MainActor.
enum Haptics {
    @MainActor static func light() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        g.impactOccurred()
    }
    @MainActor static func medium() {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare()
        g.impactOccurred()
    }
    @MainActor static func soft() {
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.prepare()
        g.impactOccurred()
    }
    @MainActor static func success() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.success)
    }
    @MainActor static func warning() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.warning)
    }
}
