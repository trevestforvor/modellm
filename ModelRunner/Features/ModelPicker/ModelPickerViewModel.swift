import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.modelrunner", category: "ModelPicker")

struct RemoteModel: Identifiable, Sendable {
    let id: String
    let serverID: UUID
    let serverName: String
    var lastMeasuredTokPerSec: Double?
    var supportsThinking: Bool

    var modelIdentity: String {
        "remote:\(serverID.uuidString):\(id)"
    }
}

struct ModelPickerSection: Identifiable {
    let id: String
    let title: String
    let models: [PickerModel]
}

struct PickerModel: Identifiable {
    let id: String
    let displayName: String
    let source: ModelSource
    let serverID: UUID?
    let serverName: String?
    let tokPerSec: Double?
    let isOnline: Bool
    let thinkingCapability: ThinkingCapability

    var supportsThinking: Bool {
        thinkingCapability != .none
    }

    func toSelectedModel() -> SelectedModel {
        SelectedModel(backendID: id, displayName: displayName, source: source)
    }
}

@Observable
@MainActor
final class ModelPickerViewModel {
    var sections: [ModelPickerSection] = []
    var isLoading: Bool = false

    func load(modelContext: ModelContext) async {
        isLoading = true

        // Batch-fetch ALL ModelUsageStats once to avoid N+1 per-model queries
        let allStats = (try? modelContext.fetch(FetchDescriptor<ModelUsageStats>())) ?? []
        let statsLookup = Dictionary(uniqueKeysWithValues: allStats.map { ($0.modelIdentity, $0) })

        var newSections: [ModelPickerSection] = []

        // Section 1: On-Device models
        let localModels = fetchLocalModels(modelContext: modelContext, statsLookup: statsLookup)
        if !localModels.isEmpty {
            newSections.append(ModelPickerSection(id: "local", title: "On Device", models: localModels))
        }

        // Section 2+: Remote servers
        let servers = fetchServers(modelContext: modelContext)
        for server in servers {
            let remoteModels = await discoverRemoteModels(server: server, modelContext: modelContext, statsLookup: statsLookup)
            if !remoteModels.isEmpty {
                newSections.append(ModelPickerSection(
                    id: server.id.uuidString,
                    title: server.name,
                    models: remoteModels
                ))
            }
        }

        sections = newSections
        isLoading = false
    }

    private func fetchLocalModels(modelContext: ModelContext, statsLookup: [String: ModelUsageStats]) -> [PickerModel] {
        let descriptor = FetchDescriptor<DownloadedModel>(
            sortBy: [SortDescriptor(\.lastUsedDate, order: .reverse)]
        )
        guard let models = try? modelContext.fetch(descriptor) else { return [] }

        return models.map { model in
            let identity = "local:\(model.repoId)"
            let stats = statsLookup[identity]
            return PickerModel(
                id: model.repoId,
                displayName: "\(model.displayName) \(model.quantization)",
                source: .local,
                serverID: nil,
                serverName: nil,
                tokPerSec: stats?.lastMeasuredTokPerSec,
                isOnline: true,
                thinkingCapability: .none
            )
        }
    }

    private func fetchServers(modelContext: ModelContext) -> [ServerConnection] {
        let descriptor = FetchDescriptor<ServerConnection>(
            sortBy: [SortDescriptor(\.addedAt)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func discoverRemoteModels(server: ServerConnection, modelContext: ModelContext, statsLookup: [String: ModelUsageStats]) async -> [PickerModel] {
        guard let url = server.parsedBaseURL else { return [] }

        let apiKey: String? = {
            guard let ref = server.apiKeyRef else { return nil }
            return KeychainService.retrieve(account: ref)
        }()

        do {
            // Use lightweight model discovery only — NOT full probe.
            // Full probe sends 3+ HTTP inference requests per server which is slow
            // and can time out, causing the server to silently disappear from the picker.
            let models = try await ServerProbe.discoverModels(baseURL: url, apiKey: apiKey, timeout: 10)

            server.isActive = true
            server.lastCheckedAt = Date()
            try? modelContext.save()

            return models.map { modelID in
                let identity = "remote:\(server.id.uuidString):\(modelID)"
                let stats = statsLookup[identity]
                return PickerModel(
                    id: modelID,
                    displayName: modelID,
                    source: .remote(serverID: server.id),
                    serverID: server.id,
                    serverName: server.name,
                    tokPerSec: stats?.lastMeasuredTokPerSec,
                    isOnline: true,
                    thinkingCapability: server.thinkingCapability(for: modelID)
                )
            }
        } catch {
            logger.warning("Failed to discover models on \(server.name): \(error)")
            server.isActive = false
            server.lastCheckedAt = Date()
            try? modelContext.save()

            // Show an offline placeholder card so the server doesn't vanish from the grid
            return [PickerModel(
                id: "offline-\(server.id.uuidString)",
                displayName: server.name,
                source: .remote(serverID: server.id),
                serverID: server.id,
                serverName: server.name,
                tokPerSec: nil,
                isOnline: false,
                thinkingCapability: .none
            )]
        }
    }
}
