import Foundation

@Observable
final class AppContainer {
    let deviceService = DeviceCapabilityService()
    let hfAPIService = HFAPIService()
    private(set) var compatibilityEngine: CompatibilityEngine?

    init() {
        Task {
            await deviceService.initialize()
            if let specs = await deviceService.specs {
                self.compatibilityEngine = CompatibilityEngine(device: specs)
            }
        }
    }
}
