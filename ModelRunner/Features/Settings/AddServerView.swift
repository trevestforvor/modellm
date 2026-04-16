import SwiftUI
import SwiftData

struct AddServerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var urlString: String = ""
    @State private var apiKey: String = ""

    @State private var probeState: ProbeState = .idle

    private let background    = Color(hex: "#0D0C18")
    private let surface       = Color(hex: "#1A1830")
    private let accent        = Color(hex: "#8B7CF0")
    private let secondaryText = Color(hex: "#9896B0")

    private enum ProbeState {
        case idle
        case probing
        case success(ServerProbe.ProbeResult)
        case failure(String)
    }

    private var probeResult: ServerProbe.ProbeResult? {
        if case .success(let result) = probeState { return result }
        return nil
    }

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && probeResult != nil
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            Form {
                Section("Server Details") {
                    TextField("Name", text: $name)
                        .foregroundStyle(.primary)

                    TextField("URL (e.g. http://localhost:11434)", text: $urlString)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(.primary)
                        .onSubmit { runProbe() }
                }
                .listRowBackground(surface)

                Section("Authentication (Optional)") {
                    SecureField("API Key", text: $apiKey)
                        .foregroundStyle(.primary)
                }
                .listRowBackground(surface)

                Section {
                    probeStatusView
                } header: {
                    Text("Server Capabilities")
                }
                .listRowBackground(surface)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Add Server")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(secondaryText)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") { saveServer() }
                    .foregroundStyle(canAdd ? accent : Color.gray)
                    .disabled(!canAdd)
            }
        }
    }

    @ViewBuilder
    private var probeStatusView: some View {
        switch probeState {
        case .idle:
            Button("Detect Capabilities") {
                runProbe()
            }
            .foregroundStyle(accent)
            .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty)

        case .probing:
            HStack(spacing: 12) {
                ProgressView()
                    .tint(accent)
                Text("Detecting server capabilities…")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "#9896B0"))
            }

        case .success(let result):
            VStack(alignment: .leading, spacing: 8) {
                Label("\(result.models.count) model(s) detected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)

                ForEach(result.supportedFormats) { format in
                    HStack {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(format.displayName)
                            .font(.caption)
                            .foregroundStyle(Color(hex: "#9896B0"))
                    }
                }

                Button("Re-detect") { runProbe() }
                    .font(.caption)
                    .foregroundStyle(accent)
                    .padding(.top, 4)
            }

        case .failure(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline)

                Button("Try Again") { runProbe() }
                    .font(.caption)
                    .foregroundStyle(accent)
            }
        }
    }

    private func runProbe() {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)),
              url.scheme != nil else {
            probeState = .failure("Invalid URL. Include http:// or https://")
            return
        }

        probeState = .probing
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        Task {
            do {
                let result = try await ServerProbe.probe(
                    baseURL: url,
                    apiKey: key.isEmpty ? nil : key
                )
                await MainActor.run { probeState = .success(result) }
            } catch {
                await MainActor.run {
                    probeState = .failure(error.localizedDescription)
                }
            }
        }
    }

    private func saveServer() {
        guard let result = probeResult else { return }

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)
        var keyRef: String? = nil
        if !trimmedKey.isEmpty {
            let ref = "server-\(UUID().uuidString)"
            KeychainService.save(key: trimmedKey, account: ref)
            keyRef = ref
        }

        let server = ServerConnection(
            name: name.trimmingCharacters(in: .whitespaces),
            baseURL: urlString.trimmingCharacters(in: .whitespaces),
            supportedFormats: result.supportedFormats,
            activeFormat: result.supportedFormats.first ?? .openAIChat,
            apiKeyRef: keyRef,
            thinkingCapabilities: result.thinkingCapabilities
        )
        modelContext.insert(server)
        dismiss()
    }
}
