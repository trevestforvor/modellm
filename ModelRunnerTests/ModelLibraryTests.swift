import Testing
import Foundation
import SwiftData
@testable import ModelRunner

/// Tests for model library management — DLST-03 (view), DLST-04 (delete), DLST-05 (switch active).
@Suite("ModelLibrary")
struct ModelLibraryTests {

    // MARK: - Helpers

    /// Creates an in-memory SwiftData ModelContainer for testing.
    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([DownloadedModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeModel(repoId: String, displayName: String, fileSizeBytes: Int64 = 2_000_000_000) -> DownloadedModel {
        DownloadedModel(
            repoId: repoId,
            displayName: displayName,
            filename: "\(repoId.split(separator: "/").last ?? "model")-Q4_K_M.gguf",
            quantization: "Q4_K_M",
            fileSizeBytes: fileSizeBytes,
            localPath: "/tmp/test-\(repoId.replacingOccurrences(of: "/", with: "-")).gguf"
        )
    }

    // MARK: - DLST-03: View library

    @Test("DownloadedModel persists and can be fetched")
    func testDownloadedModelPersistence() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let model = makeModel(repoId: "test/model-a", displayName: "Model A")
        context.insert(model)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DownloadedModel>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.repoId == "test/model-a")
        #expect(fetched.first?.displayName == "Model A")
    }

    @Test("formattedSize returns GB string for files >= 1GB")
    func testFormattedSizeGigabytes() {
        let model = makeModel(repoId: "test/big", displayName: "Big", fileSizeBytes: 3_400_000_000)
        #expect(model.formattedSize.contains("GB"))
        #expect(model.formattedSize.contains("3.4"))
    }

    @Test("formattedSize returns MB string for files < 1GB")
    func testFormattedSizeMegabytes() {
        let model = makeModel(repoId: "test/small", displayName: "Small", fileSizeBytes: 500_000_000)
        #expect(model.formattedSize.contains("MB"))
    }

    @Test("relativeLastUsed returns a non-empty string")
    func testRelativeLastUsedNonEmpty() {
        let model = makeModel(repoId: "test/rel", displayName: "Relative")
        #expect(!model.relativeLastUsed.isEmpty)
    }

    // MARK: - DLST-05: Switch active model

    @Test("setActiveModel deactivates all others and activates the target")
    @MainActor
    func testSetActiveModelDeactivatesOthers() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = LibraryService()

        let modelA = makeModel(repoId: "test/a", displayName: "A")
        let modelB = makeModel(repoId: "test/b", displayName: "B")
        let modelC = makeModel(repoId: "test/c", displayName: "C")

        context.insert(modelA)
        context.insert(modelB)
        context.insert(modelC)
        try context.save()

        // Set A active first
        try service.setActiveModel(modelA, in: [modelA, modelB, modelC], context: context)
        #expect(modelA.isActive == true)
        #expect(modelB.isActive == false)
        #expect(modelC.isActive == false)

        // Now set B active — A must be deactivated
        try service.setActiveModel(modelB, in: [modelA, modelB, modelC], context: context)
        #expect(modelA.isActive == false)
        #expect(modelB.isActive == true)
        #expect(modelC.isActive == false)
    }

    @Test("Only one model is active at a time after multiple activations")
    @MainActor
    func testOnlyOneModelIsActiveAtATime() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = LibraryService()

        let models = (0..<5).map { i in makeModel(repoId: "test/model-\(i)", displayName: "Model \(i)") }
        models.forEach { context.insert($0) }
        try context.save()

        // Activate each in sequence
        for model in models {
            try service.setActiveModel(model, in: models, context: context)
        }

        // Only the last one should be active
        let activeCount = models.filter { $0.isActive }.count
        #expect(activeCount == 1)
        #expect(models.last?.isActive == true)
    }

    // MARK: - DLST-04: Delete model

    @Test("deleteModel removes SwiftData record")
    @MainActor
    func testDeleteModelRemovesRecord() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = LibraryService()

        let model = makeModel(repoId: "test/to-delete", displayName: "To Delete")
        // Use a path that won't exist — FileManager.fileExists returns false, so removeItem is skipped
        context.insert(model)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<DownloadedModel>()).count == 1)

        try service.deleteModel(model, context: context)

        #expect(try context.fetch(FetchDescriptor<DownloadedModel>()).count == 0)
    }

    @Test("deleteModel clears resume data from UserDefaults")
    @MainActor
    func testDeleteModelClearsResumeData() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let service = LibraryService()

        let model = makeModel(repoId: "test/resume-clear", displayName: "Resume Clear")
        // Simulate stored resume data
        UserDefaults.standard.set(Data([0x01, 0x02]), forKey: "resumeData_test/resume-clear")
        context.insert(model)
        try context.save()

        try service.deleteModel(model, context: context)

        #expect(UserDefaults.standard.data(forKey: "resumeData_test/resume-clear") == nil)
    }

    // MARK: - Storage totals

    @Test("totalStorageUsed sums all model sizes correctly")
    @MainActor
    func testTotalStorageUsed() {
        let service = LibraryService()
        let models = [
            makeModel(repoId: "a", displayName: "A", fileSizeBytes: 2_000_000_000),
            makeModel(repoId: "b", displayName: "B", fileSizeBytes: 3_000_000_000),
        ]
        #expect(service.totalStorageUsed(models: models) == 5_000_000_000)
    }

    @Test("formattedTotalStorage returns GB string for large totals")
    @MainActor
    func testFormattedTotalStorageGB() {
        let service = LibraryService()
        let models = [makeModel(repoId: "a", displayName: "A", fileSizeBytes: 5_000_000_000)]
        let formatted = service.formattedTotalStorage(models: models)
        #expect(formatted.contains("GB"))
        #expect(formatted.contains("5.0"))
    }
}
