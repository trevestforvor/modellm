import SwiftUI

@main
struct ModelRunnerApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(container)
        }
    }
}
