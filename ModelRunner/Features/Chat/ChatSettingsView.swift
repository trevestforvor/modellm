import SwiftUI
import SwiftData

/// Per-model inference parameter settings sheet.
///
/// Presents preset pills (Precise/Balanced/Creative), an Advanced disclosure group
/// with temperature and top-p sliders, and the system prompt section.
/// All writes go directly to the SwiftData DownloadedModel — no intermediate state.
struct ChatSettingsView: View {
    @Bindable var model: DownloadedModel
    @Environment(\.dismiss) private var dismiss

    // Advanced section starts collapsed
    @State private var advancedExpanded: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        presetSection
                        advancedSection
                        systemPromptSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Model Settings")
                        .font(.outfit(.headline, weight: .semibold))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Text("Done")
                            .font(.figtree(.body, weight: .medium))
                            .foregroundStyle(Color(hex: "#4D6CF2"))
                    }
                }
            }
        }
    }

    // MARK: - Preset Pills

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STYLE")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "#9896B0"))

            HStack(spacing: 8) {
                ForEach(InferencePreset.allCases) { preset in
                    let isSelected = isPresetActive(preset)
                    Button {
                        preset.apply(to: model)
                    } label: {
                        Text(preset.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isSelected ? .white : Color(hex: "#9896B0"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color(hex: "#4D6CF2") : Color.clear)
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                isSelected ? Color.clear : Color(hex: "#302E42"),
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glassBackground)
    }

    /// Returns true when the model's current temperature + topP match the preset within floating-point tolerance.
    private func isPresetActive(_ preset: InferencePreset) -> Bool {
        abs(model.temperature - preset.temperature) < 0.01 &&
        abs(model.topP - preset.topP) < 0.01
    }

    // MARK: - Advanced Parameters

    private var advancedSection: some View {
        DisclosureGroup(
            isExpanded: $advancedExpanded,
            content: {
                VStack(spacing: 20) {
                    temperatureSlider
                    topPSlider
                }
                .padding(.top, 12)
            },
            label: {
                Text("Advanced")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
            }
        )
        .padding()
        .background(glassBackground)
        .tint(Color(hex: "#4D6CF2"))
    }

    private var temperatureSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Temperature")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                Spacer()
                Text(String(format: "%.1f", model.temperature))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Color(hex: "#9896B0"))
            }
            Slider(
                value: $model.temperature,
                in: 0.0...2.0,
                step: 0.1
            )
            .tint(Color(hex: "#4D6CF2"))
            HStack {
                Text("0.0")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#6B6980"))
                Spacer()
                Text("2.0")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#6B6980"))
            }
        }
    }

    private var topPSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Top-P")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                Spacer()
                Text(String(format: "%.2f", model.topP))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Color(hex: "#9896B0"))
            }
            Slider(
                value: $model.topP,
                in: 0.0...1.0,
                step: 0.05
            )
            .tint(Color(hex: "#4D6CF2"))
            HStack {
                Text("0.0")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#6B6980"))
                Spacer()
                Text("1.0")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#6B6980"))
            }
        }
    }

    // MARK: - System Prompt

    private var systemPromptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SYSTEM PROMPT")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color(hex: "#9896B0"))

            // Preset chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SystemPromptPreset.allCases.filter { $0 != .custom }) { preset in
                        let isSelected = model.systemPrompt == preset.prompt
                        Button {
                            model.systemPrompt = preset.prompt
                        } label: {
                            Text(preset.displayName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isSelected ? .white : Color(hex: "#9896B0"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color(hex: "#4D6CF2") : Color.clear)
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(
                                                    isSelected ? Color.clear : Color(hex: "#302E42"),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Editable text field
            TextEditor(text: $model.systemPrompt)
                .frame(minHeight: 100)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#0D0C18").opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color(hex: "#302E42"), lineWidth: 0.5)
                        )
                )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glassBackground)
    }

    // MARK: - Shared Styling

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(hex: "#1A1830").opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(hex: "#302E42"), lineWidth: 0.5)
            )
    }
}
