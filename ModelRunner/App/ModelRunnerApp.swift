import SwiftUI
import SwiftData

// MARK: - AppDelegate (required for background URLSession lifecycle — DLST-02)

/// Handles iOS re-launch events when a background download completes while the app is backgrounded.
/// Critical: must call completionHandler AFTER reconnecting DownloadService — see P-01 in RESEARCH.md.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == DownloadService.backgroundSessionIdentifier else {
            completionHandler()
            return
        }
        // Reconnect DownloadService FIRST (instantiating it recreates the background URLSession
        // with the same identifier, allowing iOS to deliver pending delegate events).
        // AppContainer.shared provides the singleton — Plan 02 implements the full handler.
        Task {
            await AppContainer.shared.downloadService.setBackgroundCompletionHandler(completionHandler)
        }
    }
}

// MARK: - App Entry Point

@main
struct ModelRunnerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // AppContainer is a shared singleton so AppDelegate can access downloadService
    @State private var container = AppContainer.shared

    // ModelContainer: DownloadedModel persists in Application Support (not Caches — see P-07)
    // isExcludedFromBackup is set per-file on GGUF blobs, not on the SwiftData store itself.
    private static let modelContainer: ModelContainer = {
        let schema = Schema([DownloadedModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(container)
        }
        .modelContainer(Self.modelContainer)
    }
}
