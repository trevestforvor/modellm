import Testing
import SwiftData
@testable import ModelRunner

/// Tests for DownloadedModel persistence — covers DLST-03 (view library), DLST-04 (delete), DLST-05 (switch active).
/// Wave 0: All tests are RED stubs. Plan 04 replaces Issue.record() with real assertions.
@Suite("ModelLibrary")
struct ModelLibraryTests {

    // DLST-03: User can view all downloaded models with size and last-used date
    @Test("DownloadedModel persists across context save and fetch")
    func testDownloadedModelPersistence() async throws {
        Issue.record("STUB — implement in Plan 04 Task 1")
    }

    @Test("Library query sorts by lastUsedDate descending")
    func testLibrarySortsByLastUsedDateDescending() async throws {
        Issue.record("STUB — implement in Plan 04 Task 1")
    }

    @Test("formattedSize returns GB string for files >= 1GB")
    func testFormattedSizeGigabytes() throws {
        let model = DownloadedModel(
            repoId: "test/model",
            displayName: "Test",
            filename: "test.gguf",
            quantization: "Q4_K_M",
            fileSizeBytes: 3_400_000_000,
            localPath: "/tmp/test.gguf"
        )
        // This assertion can run now — formattedSize is a pure computed property
        #expect(model.formattedSize.contains("GB"))
    }

    // DLST-04: User can delete downloaded models to free storage
    @Test("Deleting DownloadedModel removes SwiftData record and triggers file deletion")
    func testDeleteRemovesModelAndFile() async throws {
        Issue.record("STUB — implement in Plan 04 Task 3")
    }

    @Test("Delete confirmation alert shows correct size freed")
    func testDeleteConfirmationShowsSize() async throws {
        Issue.record("STUB — implement in Plan 04 Task 3")
    }

    // DLST-05: User can switch between downloaded models (only one active at a time)
    @Test("Setting one model active deactivates all others")
    func testOnlyOneModelIsActiveAtATime() async throws {
        Issue.record("STUB — implement in Plan 04 Task 4")
    }

    @Test("Active model isActive flag persists across context save")
    func testActiveModelPersistsAcrossSave() async throws {
        Issue.record("STUB — implement in Plan 04 Task 4")
    }
}
