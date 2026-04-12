import SwiftUI
import SwiftData

struct ServerDetailView: View {
    @Bindable var server: ServerConnection
    @Environment(\.modelContext) private var modelContext

    @State private var apiKeyInput: String = ""
    @State private var redetectState: RedetectState = .idle

    private let background    = Color(hex: "#0D0C18")
    private let surface       = Color(hex: "#1A1830")
    private let accent        = Color(hex: "#8B7CF0")
    private let secondaryText = Color(hex: "#9896B0")

    private enum RedetectState {
        case idle
        case probing
        case success(String)   // summary message
        case failure(String)
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            Form {
                // MARK: - Identity
                Section("Server") {
                    LabeledTextField(label: "Name", text: $server.name)
                    LabeledTextField(label: "URL", text: $server.baseURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .listRowBackground(surface)

                // MARK: - Format
                Section("API Format") {
                    Picker("Active Format", selection: $server.activeFormat) {
                        ForEach(server.parsedSupportedFormats) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .foregroundStyle(.primary)

                    if !server.parsedSupportedFormats.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Supported Formats")
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                            ForEach(server.parsedSupportedFormats) { format in
                                Text("• \(format.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(secondaryText)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    redetectButton
                }
                .listRowBackground(surface)

                // MARK: - Auth
                Section("Authentication") {
                    SecureField("API Key", text: $apiKeyInput)
                        .foregroundStyle(.primary)

                    HStack(spacing: 16) {
                        Button("Save Key") {
                            saveAPIKey()
                        }
                        .foregroundStyle(accent)
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)

                        if server.apiKeyRef != nil {
                            Button("Remove Key") {
                                removeAPIKey()
                            }
                            .foregroundStyle(.red)
                        }
                    }
                }
                .listRowBackground(surface)

                // MARK: - Status
                Section("Status") {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(server.isActive ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(server.isActive ? "Connected" : "Offline")
                            .foregroundStyle(.primary)
                    }

                    if let lastChecked = server.lastCheckedAt {
                        HStack {
                            Text("Last Checked")
                                .foregroundStyle(secondaryText)
                            Spacer()
                            Text(lastChecked, style: .relative)
                                .font(.subheadline)
                                .foregroundStyle(secondaryText)
                        }
                    }
                }
                .listRowBackground(surface)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(server.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load existing key placeholder (don't reveal actual key)
            if server.apiKeyRef != nil {
                apiKeyInput = ""
            }
        }
    }

    @ViewBuilder
    private var redetectButton: some View {
        switch redetectState {
        case .idle:
            Button("Re-detect Formats") { runRedetect() }
                .foregroundStyle(accent)

        case .probing:
            HStack(spacing: 10) {
                ProgressView()
                    .tint(accent)
                    .scaleEffect(0.8)
                Text("Probing server…")
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)
            }

        case .success(let msg):
            VStack(alignment: .leading, spacing: 4) {
                Label(msg, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
                Button("Re-detect Again") { runRedetect() }
                    .font(.caption)
                    .foregroundStyle(accent)
            }

        case .failure(let msg):
            VStack(alignment: .leading, spacing: 4) {
                Label(msg, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline)
                Button("Try Again") { runRedetect() }
                    .font(.caption)
                    .foregroundStyle(accent)
            }
        }
    }

    private func runRedetect() {
        guard let url = URL(string: server.baseURL), url.scheme != nil else {
            redetectState = .failure("Invalid server URL.")
            return
        }

        redetectState = .probing
        let existingKey: String? = server.apiKeyRef.flatMap { KeychainService.retrieve(account: $0) }

        Task {
            do {
                let result = try await ServerProbe.probe(baseURL: url, apiKey: existingKey)
                await MainActor.run {
                    server.supportedFormats = result.supportedFormats.map(\.rawValue)
                    if !result.supportedFormats.isEmpty {
                        server.activeFormat = result.supportedFormats.first!
                    }
                    server.isActive = true
                    server.lastCheckedAt = Date()
                    server.updateThinkingCapabilities(result.thinkingCapabilities)

                    // Build status message
                    let thinkingModels = result.thinkingCapabilities.filter { $0.value != .none }
                    var status = "\(result.supportedFormats.count) format(s), \(result.models.count) model(s)"
                    if !thinkingModels.isEmpty {
                        let labels = thinkingModels.map { "\($0.key): \($0.value == .toggleable ? "toggleable" : "always on")" }
                        status += ". Thinking: \(labels.joined(separator: ", "))"
                    }
                    redetectState = .success(status)
                }
            } catch {
                await MainActor.run {
                    server.isActive = false
                    server.lastCheckedAt = Date()
                    redetectState = .failure(error.localizedDescription)
                }
            }
        }
    }

    private func saveAPIKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }

        if let ref = server.apiKeyRef {
            KeychainService.save(key: key, account: ref)
        } else {
            let ref = "server-\(server.id.uuidString)"
            KeychainService.save(key: key, account: ref)
            server.apiKeyRef = ref
        }
        apiKeyInput = ""
    }

    private func removeAPIKey() {
        if let ref = server.apiKeyRef {
            KeychainService.delete(account: ref)
        }
        server.apiKeyRef = nil
        apiKeyInput = ""
    }
}

// MARK: - Helper

private struct LabeledTextField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        TextField(label, text: $text)
            .foregroundStyle(.primary)
    }
}
