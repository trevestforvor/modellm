import SwiftUI

struct ChatSettingsView: View {
    @Binding var settings: ChatSettings
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("System Prompt") {
                    ForEach(SystemPromptPreset.allCases.filter { $0 != .custom }) { preset in
                        Button {
                            settings.selectedPreset = preset
                            settings.systemPrompt = preset.prompt
                        } label: {
                            HStack {
                                Text(preset.displayName)
                                    .foregroundStyle(.white)
                                Spacer()
                                if settings.selectedPreset == preset {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color(hex: "#8B7CF0"))
                                }
                            }
                        }
                    }
                }

                Section("Custom Prompt") {
                    TextEditor(text: $settings.systemPrompt)
                        .frame(minHeight: 100)
                        .onChange(of: settings.systemPrompt) { _, newValue in
                            // If user edits, auto-match preset or fall back to custom
                            let matchesPreset = SystemPromptPreset.allCases
                                .filter { $0 != .custom }
                                .first { $0.prompt == newValue }
                            settings.selectedPreset = matchesPreset ?? .custom
                        }
                }
            }
            .navigationTitle("Chat Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        settings.save()
                        dismiss()
                    }
                    .foregroundStyle(Color(hex: "#8B7CF0"))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#0D0C18"))
        }
    }
}
