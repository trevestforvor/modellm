import Foundation
import OSLog
import SwiftData

/// Registers a GGUF model that is bundled inside the app's Resources as a
/// `DownloadedModel` SwiftData entity at first launch.
///
/// This exists purely so the simulator (which gets wiped frequently) doesn't
/// require re-downloading a model after every reset. On real devices, the file
/// isn't bundled (excluded via `EXCLUDED_SOURCE_FILE_NAMES[sdk=iphoneos*]`),
/// and the installer is gated behind `#if targetEnvironment(simulator)` so the
/// device path is a no-op even if the file ever did sneak in.
enum BundledModelInstaller {
    private static let logger = Logger(subsystem: "com.modelrunner", category: "BundledModelInstaller")

    /// Bundle identity for the bundled model — chosen so it sorts/displays
    /// distinctly from any HF-downloaded copies of the same weights.
    private static let bundledRepoID = "bundled/SmolLM2-360M-Instruct"
    private static let bundledFilenameStem = "SmolLM2-360M-Instruct-Q8_0"
    private static let bundledFilenameExt = "gguf"
    private static let bundledDisplayName = "SmolLM2-360M-Instruct (Bundled)"
    private static let bundledQuantization = "Q8_0"

    /// Idempotently insert a `DownloadedModel` record pointing at the bundled GGUF.
    /// Safe to call on every launch — it short-circuits when the record already exists
    /// and its `localPath` resolves on disk.
    @MainActor
    static func installIfNeeded(modelContext: ModelContext) {
        // Temporarily enabled on device too while diagnosing the simulator-vs-device
        // SmolLM2 output discrepancy. Restore `#if targetEnvironment(simulator)` once
        // we've confirmed the model behaves correctly on real hardware.
        let repoID = bundledRepoID
        let descriptor = FetchDescriptor<DownloadedModel>(
            predicate: #Predicate { $0.repoId == repoID }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            if FileManager.default.fileExists(atPath: existing.localPath) {
                logger.debug("Bundled model already registered at \(existing.localPath, privacy: .public)")
                return
            } else {
                // Stale record — the bundle path may have changed (e.g. derived data
                // moved between Xcode runs). Delete and re-insert below.
                logger.info("Bundled model record exists but file missing on disk — re-registering")
                modelContext.delete(existing)
            }
        }

        guard let bundleURL = Bundle.main.url(
            forResource: bundledFilenameStem,
            withExtension: bundledFilenameExt
        ) else {
            logger.info("Bundled GGUF not present in app bundle — skipping install")
            return
        }

        let fileSize: Int64 = {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: bundleURL.path),
                  let size = attrs[.size] as? NSNumber else {
                return 0
            }
            return size.int64Value
        }()

        let model = DownloadedModel(
            repoId: bundledRepoID,
            displayName: bundledDisplayName,
            filename: "\(bundledFilenameStem).\(bundledFilenameExt)",
            quantization: bundledQuantization,
            fileSizeBytes: fileSize,
            localPath: bundleURL.path
        )
        modelContext.insert(model)

        do {
            try modelContext.save()
            logger.info("Registered bundled model at \(bundleURL.path, privacy: .public) (\(fileSize) bytes)")
        } catch {
            logger.error("Failed to save bundled model registration: \(error.localizedDescription, privacy: .public)")
        }
    }
}
