import SwiftUI
import SwiftData

// MARK: - AppDelegate (required for background URLSession lifecycle — DLST-02)

/// Handles iOS re-launch events when a background download completes while the app is backgrounded.
/// Critical: must call completionHandler AFTER reconnecting DownloadService — see P-01 in RESEARCH.md.
@MainActor class AppDelegate: NSObject, UIApplicationDelegate {
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

    // First-launch gate — false on fresh install, true after welcome screen is dismissed
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    // Pending guided model ID — set by WelcomeView, consumed by ContentView on appear
    @AppStorage("guidedOnboardingModelId") private var guidedOnboardingModelId: String = ""

    // ModelContainer: DownloadedModel persists in Application Support (not Caches — see P-07)
    // isExcludedFromBackup is set per-file on GGUF blobs, not on the SwiftData store itself.
    private static let modelContainer: ModelContainer = {
        let schema = Schema([DownloadedModel.self, Conversation.self, Message.self, ServerConnection.self, ModelUsageStats.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environment(container)
            } else {
                WelcomeView { path in
                    switch path {
                    case .guided(let model):
                        if let model = model {
                            // Store model repoId — ContentView reads this on appear and activates
                            guidedOnboardingModelId = model.repoId
                        }
                        // nil model (no downloads) → fall back to Browse tab (same as .browse)
                    case .browse:
                        break  // ContentView shows Browse tab by default
                    }
                    hasCompletedOnboarding = true
                }
                .environment(container)
            }
        }
        .modelContainer(Self.modelContainer)
    }
}
