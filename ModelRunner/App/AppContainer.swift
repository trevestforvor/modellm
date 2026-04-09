import Foundation

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

    // MARK: - Init

    private init() {
        Task {
            await deviceService.initialize()
            if let specs = await deviceService.specs {
                self.compatibilityEngine = CompatibilityEngine(device: specs)
            }
        }
    }
}
