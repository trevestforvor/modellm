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
    /// Thinking capabilities per model ID — JSON-encoded [String: String] (modelID → ThinkingCapability.rawValue)
    var thinkingCapabilitiesJSON: String?

    init(
        name: String,
        baseURL: String,
        supportedFormats: [APIFormat],
        activeFormat: APIFormat,
        apiKeyRef: String? = nil,
        thinkingCapabilities: [String: ThinkingCapability] = [:]
    ) {
        self.id = UUID()
        self.name = name
        self.baseURL = baseURL
        self.supportedFormats = supportedFormats.map(\.rawValue)
        self.activeFormatRaw = activeFormat.rawValue
        self.apiKeyRef = apiKeyRef
        self.isActive = true
        self.addedAt = Date()
        self.thinkingCapabilitiesJSON = Self.encodeThinkingCaps(thinkingCapabilities)
    }

    /// Get thinking capability for a specific model
    func thinkingCapability(for modelID: String) -> ThinkingCapability {
        guard let json = thinkingCapabilitiesJSON,
              let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data),
              let rawValue = dict[modelID],
              let cap = ThinkingCapability(rawValue: rawValue) else {
            return .none
        }
        return cap
    }

    /// Update thinking capabilities from a probe result
    func updateThinkingCapabilities(_ caps: [String: ThinkingCapability]) {
        thinkingCapabilitiesJSON = Self.encodeThinkingCaps(caps)
    }

    private static func encodeThinkingCaps(_ caps: [String: ThinkingCapability]) -> String? {
        guard !caps.isEmpty else { return nil }
        let stringDict = caps.mapValues(\.rawValue)
        guard let data = try? JSONEncoder().encode(stringDict) else { return nil }
        return String(data: data, encoding: .utf8)
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
