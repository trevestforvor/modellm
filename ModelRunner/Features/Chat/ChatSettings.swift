import Foundation

/// User-configurable inference settings. Stored in UserDefaults.
/// v1 scope: system prompt only. Temperature/top-p are Phase 5.
struct ChatSettings: Codable {
    var systemPrompt: String
    var selectedPreset: SystemPromptPreset

    static let defaultSettings = ChatSettings(
        systemPrompt: SystemPromptPreset.helpful.prompt,
        selectedPreset: .helpful
    )

    private static let userDefaultsKey = "ChatSettings"

    static func load() -> ChatSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(ChatSettings.self, from: data) else {
            return .defaultSettings
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: ChatSettings.userDefaultsKey)
        }
    }
}

enum SystemPromptPreset: String, Codable, CaseIterable, Identifiable {
    case helpful = "helpful"
    case creative = "creative"
    case coder = "coder"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .helpful: return "Helpful Assistant"
        case .creative: return "Creative Writer"
        case .coder: return "Code Helper"
        case .custom: return "Custom"
        }
    }

    var prompt: String {
        switch self {
        case .helpful: return "You are a helpful, harmless, and honest assistant."
        case .creative: return "You are a creative writing assistant. Be imaginative, descriptive, and engaging."
        case .coder: return "You are an expert coding assistant. Write clean, well-commented code and explain your reasoning."
        case .custom: return ""
        }
    }
}
