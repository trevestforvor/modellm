import SwiftUI

struct ContentView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .browse

    enum Tab { case browse, library, chat }

    private let accent        = Color(hex: "#8B7CF0")
    private let unselected    = Color(hex: "#6B6980")
    private let tabBarSurface = Color(hex: "#0D0C18")

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Browse Hugging Face models (Phase 2)
            BrowseView()
                .tabItem {
                    Label("Browse", systemImage: "square.grid.2x2")
                }
                .tag(Tab.browse)

            // Tab 2: Downloaded model library (Phase 3)
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "internaldrive")
                }
                .tag(Tab.library)

            chatPlaceholder
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.fill")
                }
                .tag(Tab.chat)
        }
        .tint(accent)
        // Inject ModelContext into DownloadService so completed downloads create SwiftData records
        .task {
            await container.downloadService.setModelContext(modelContext)
        }
        // Toolbar appearance for dark tab bar
        .onAppear { configureTabBarAppearance() }
        // Persistent download progress bar — sits above tab bar (D-01)
        // Uses safeAreaInset to avoid covering scroll content on small screens (P-08)
        .safeAreaInset(edge: .bottom) {
            if container.downloadService.state.isActive {
                DownloadProgressBar(
                    state: container.downloadService.state,
                    onCancel: {
                        Task {
                            await container.downloadService.cancelDownload()
                        }
                    }
                )
            }
        }
    }

    private var chatPlaceholder: some View {
        ZStack {
            Color(hex: "#0F0E1A").ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "bubble.left.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color(hex: "#6B6980"))
                Text("Chat")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "#9896B0"))
                Text("Download a model to start chatting")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "#6B6980"))
            }
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        // #0D0C18 at 95% opacity
        appearance.backgroundColor = UIColor(Color(hex: "#0D0C18").opacity(0.95))
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    ContentView()
        .environment(AppContainer.shared)
}
