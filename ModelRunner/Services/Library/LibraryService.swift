import Foundation
import SwiftData

/// Business logic for the Library tab — manages active model selection and model deletion.
/// All write operations run on @MainActor (required for SwiftData modelContext operations).
@MainActor
final class LibraryService {

    // MARK: - Active Model Selection (DLST-05)

    /// Sets the given model as active, deactivating all others first.
    /// Enforces "only one active at a time" atomically on MainActor (P-06).
    /// D-10: active model is what Phase 4's InferenceService loads.
    func setActiveModel(_ model: DownloadedModel, in models: [DownloadedModel], context: ModelContext) throws {
        // Deactivate all models (including the target) before setting active.
        // This prevents any window where two models are both active (P-06).
        for m in models {
            m.isActive = false
        }
        // Now set the target as active
        model.isActive = true
        model.lastUsedDate = Date()

        try context.save()
    }

    /// Toggles active state — if model is already active, deactivates without setting another.
    /// Use setActiveModel for explicit selection; this is used by the Library tap gesture.
    func toggleActive(_ model: DownloadedModel, in models: [DownloadedModel], context: ModelContext) throws {
        if model.isActive {
            // Tapping active model again deactivates it (no active model state)
            model.isActive = false
        } else {
            try setActiveModel(model, in: models, context: context)
            return
        }
        try context.save()
    }

    // MARK: - Model Deletion (DLST-04)

    /// Deletes a model from the Library:
    /// 1. Removes the GGUF file from disk (FileManager)
    /// 2. Deletes the SwiftData record
    /// D-09: confirmation alert with size freed is shown by LibraryView BEFORE calling this.
    func deleteModel(_ model: DownloadedModel, context: ModelContext) throws {
        let localPath = model.localPath

        // Step 1: Remove file from Application Support
        let fileURL = URL(filePath: localPath)
        if FileManager.default.fileExists(atPath: localPath) {
            try FileManager.default.removeItem(at: fileURL)
        }

        // Step 2: Clear resume data (if any) from UserDefaults
        UserDefaults.standard.removeObject(forKey: "resumeData_\(model.repoId)")

        // Step 3: Delete SwiftData record
        context.delete(model)
        try context.save()
    }

    // MARK: - Storage Aggregation (D-13)

    /// Total bytes used by all downloaded models on disk.
    func totalStorageUsed(models: [DownloadedModel]) -> Int64 {
        models.reduce(0) { $0 + $1.fileSizeBytes }
    }

    /// Formatted total storage string e.g. "12.4 GB"
    func formattedTotalStorage(models: [DownloadedModel]) -> String {
        let total = Double(totalStorageUsed(models: models))
        if total >= 1_000_000_000 {
            return String(format: "%.1f GB", total / 1_000_000_000)
        } else {
            return String(format: "%.0f MB", total / 1_000_000)
        }
    }

    /// Formatted free storage string from device service.
    func formattedFreeStorage(freeBytes: Int64) -> String {
        let free = Double(freeBytes)
        if free >= 1_000_000_000 {
            return String(format: "%.1f GB", free / 1_000_000_000)
        } else {
            return String(format: "%.0f MB", free / 1_000_000)
        }
    }
}
