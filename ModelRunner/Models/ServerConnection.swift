import Foundation
import SwiftData

@Model
final class ServerConnection {
    @Attribute(.unique) var id: UUID
    var name: String
    var baseURL: String
    var supportedFormats: [String]  // APIFormat rawValues — SwiftData can't store custom enums in arrays
    var activeFormatRaw: String     // APIFormat rawValue
    var apiKeyRef: String?          // Keychain item identifier, NOT the actual key
    var isActive: Bool
    var addedAt: Date
    var lastCheckedAt: Date?

    init(
        name: String,
        baseURL: String,
        supportedFormats: [APIFormat],
        activeFormat: APIFormat,
        apiKeyRef: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.baseURL = baseURL
        self.supportedFormats = supportedFormats.map(\.rawValue)
        self.activeFormatRaw = activeFormat.rawValue
        self.apiKeyRef = apiKeyRef
        self.isActive = true
        self.addedAt = Date()
    }

    var activeFormat: APIFormat {
        get { APIFormat(rawValue: activeFormatRaw) ?? .openAIChat }
        set { activeFormatRaw = newValue.rawValue }
    }

    var parsedSupportedFormats: [APIFormat] {
        supportedFormats.compactMap { APIFormat(rawValue: $0) }
    }

    var parsedBaseURL: URL? {
        URL(string: baseURL)
    }
}
