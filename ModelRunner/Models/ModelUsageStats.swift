import Foundation
import SwiftData

@Model
final class ModelUsageStats {
    @Attribute(.unique) var modelIdentity: String
    var lastMeasuredTokPerSec: Double?
    var totalGenerations: Int
    var lastUsedAt: Date

    init(modelIdentity: String) {
        self.modelIdentity = modelIdentity
        self.totalGenerations = 0
        self.lastUsedAt = Date()
    }

    func recordGeneration(tokPerSec: Double) {
        lastMeasuredTokPerSec = tokPerSec
        totalGenerations += 1
        lastUsedAt = Date()
    }
}
