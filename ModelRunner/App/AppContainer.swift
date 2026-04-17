import Foundation
import SwiftData

/// Central dependency container for ModelRunner.
/// @Observable — SwiftUI views receive updates when properties change.
/// Singleton pattern required so AppDelegate can access downloadService during background wake.
@Observable
final class AppContainer {
    // MARK: - Singleton

    /// Shared instance — used by AppDelegate for background URLSession reconnection (P-01).
    /// SwiftUI also references this via @State in ModelRunnerApp.
    static let shared = AppContainer()

    // MARK: - Services (Phase 1)

    let deviceService = DeviceCapabilityService()
    let hfAPIService = HFAPIService()
    private(set) var compatibilityEngine: CompatibilityEngine?

    // MARK: - Services (Phase 3)

    /// Download manager — instantiated eagerly so background URLSession is recreated
    /// with the same identifier before any UI loads (critical for P-01 background session reconnect).
    let downloadService = DownloadService()

    // MARK: - Services (Phase 4)

    /// Inference engine — one actor instance per app. Holds one LlamaSession resident.
    /// Call loadModel() before generate(). Never recreate per message (KV cache is expensive).
    let inferenceService = InferenceService()

    // MARK: - Active Model (Phase 4 — stub; Phase 5 wires Library → Chat selection)

    /// URL to the currently active GGUF model file on disk.
    /// Set by LibraryView when user selects a model to chat with.
    var activeModelURL: URL? = nil

    /// Display name of the active model (e.g. "Llama-3.2-1B").
    var activeModelName: String? = nil

    /// Quantization label of the active model (e.g. "Q4_K_M").
    var activeModelQuant: String? = nil

    // MARK: - Unified Model Selection

    /// Currently selected model — persisted to UserDefaults
    var selectedModel: SelectedModel? {
        didSet {
            if let model = selectedModel,
               let data = try? JSONEncoder().encode(model) {
                UserDefaults.standard.set(data, forKey: "selectedModel")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedModel")
            }
        }
    }

    // MARK: - Init

    private init() {
        Task { @MainActor in
            await deviceService.initialize()
            if let specs = await deviceService.specs {
                self.compatibilityEngine = CompatibilityEngine(device: specs)
            }
        }

        // Restore selected model from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "selectedModel"),
           let model = try? JSONDecoder().decode(SelectedModel.self, from: data) {
            self.selectedModel = model
        }
    }

    /// Build InferenceParams scoped to this device's chip context window cap.
    /// Reads per-model temperature, topP, and systemPrompt from SwiftData when an active model exists.
    /// Falls back to defaults if no active model or device profile is not yet loaded.
    func inferenceParams(activeModel: DownloadedModel? = nil) -> InferenceParams {
        let contextCap = compatibilityEngine?.device.chipProfile.contextWindowCap ?? 2048
        if let model = activeModel {
            return InferenceParams.from(model: model, contextWindowCap: contextCap)
        }
        return InferenceParams.default(contextWindowCap: contextCap)
    }

    func buildLocalBackend(for model: DownloadedModel) -> LocalInferenceBackend {
        let params = inferenceParams(activeModel: model)
        return LocalInferenceBackend(
            repoId: model.repoId,
            displayName: model.displayName,
            modelURL: model.resolvedFileURL,
            inferenceService: inferenceService,
            inferenceParams: params
        )
    }

    /// Build an InferenceBackend for the given picker model selection.
    func buildBackend(for pickerModel: PickerModel, modelContext: ModelContext) -> (any InferenceBackend)? {
        guard case .remote(let serverID) = pickerModel.source else {
            return nil  // Local backend not yet implemented
        }

        // SwiftData #Predicate can't compare UUID values or traverse .uuidString —
        // fetch all servers and filter in memory (server list is small).
        let allServers = (try? modelContext.fetch(FetchDescriptor<ServerConnection>())) ?? []
        guard let server = allServers.first(where: { $0.id == serverID }),
              let baseURL = server.parsedBaseURL else { return nil }

        let apiKey: String? = {
            guard let ref = server.apiKeyRef else { return nil }
            return KeychainService.retrieve(account: ref)
        }()

        let adapter: any APIAdapter = switch server.activeFormat {
        case .openAIChat: OpenAIChatAdapter()
        case .openAILegacy: OpenAILegacyAdapter()
        case .anthropicMessages: AnthropicMessagesAdapter()
        }

        return RemoteInferenceBackend(
            modelID: pickerModel.id,
            serverID: server.id,
            serverName: server.name,
            baseURL: baseURL,
            adapter: adapter,
            apiKey: apiKey
        )
    }
}
