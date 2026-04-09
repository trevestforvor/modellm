import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .browse
    // Onboarding guided path: if set, activate this model and switch to Chat on appear
    @AppStorage("guidedOnboardingModelId") private var guidedOnboardingModelId: String = ""

    enum Tab { case browse, library, chat }

    private let accent        = Color(hex: "#8B7CF0")
    private let unselected    = Color(hex: "#6B6980")
    private let tabBarSurface = Color(hex: "#0D0C18")

    var body: some View {
        ZStack {
            // Root gradient — visible on all tabs through transparent backgrounds
            AppBackground()

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

            NavigationStack {
                ChatView(
                    activeModelURL: container.activeModelURL,
                    activeModelName: container.activeModelName ?? "",
                    activeModelQuant: container.activeModelQuant ?? ""
                )
            }
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
        // Guided onboarding: if a model was pre-selected during onboarding, activate and switch to Chat
        .onAppear {
            guard !guidedOnboardingModelId.isEmpty else { return }
            let repoId = guidedOnboardingModelId
            guidedOnboardingModelId = ""  // consume once
            // Find the model in SwiftData and wire it to AppContainer (Phase 5 active model wiring)
            do {
                let descriptor = FetchDescriptor<DownloadedModel>(
                    predicate: #Predicate { $0.repoId == repoId }
                )
                if let model = try modelContext.fetch(descriptor).first {
                    container.activeModelURL = URL(filePath: model.localPath)
                    container.activeModelName = model.displayName
                    container.activeModelQuant = model.quantization
                    selectedTab = .chat
                }
            } catch {
                // Non-fatal — fall back to default Browse tab with no active model
            }
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
        } // ZStack
    }

    private func configureTabBarAppearance() {
        // Tab bar: solid dark surface
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color(hex: "#0D0C18").opacity(0.95))
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Navigation bar: transparent so MeshGradient shows through
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = .clear
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }
}

#Preview {
    ContentView()
        .environment(AppContainer.shared)
}
