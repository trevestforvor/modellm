import Foundation

@Observable
final class AppContainer {
    let deviceService = DeviceCapabilityService()

    init() {
        Task {
            await deviceService.initialize()
        }
    }
}
