import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .chat
    @AppStorage("guidedOnboardingModelId") private var guidedOnboardingModelId: String = ""

    enum Tab { case chat, models }

    private let accent = Color(hex: "#8B7CF0")

    var body: some View {
        ZStack {
            AppBackground()

            TabView(selection: $selectedTab) {
                // Tab 1: Chat (left)
                NavigationStack {
                    ChatView(
                        activeModelURL: container.activeModelURL,
                        activeModelName: container.selectedModel?.displayName ?? container.activeModelName ?? "",
                        activeModelQuant: container.activeModelQuant ?? ""
                    )
                }
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.fill")
                }
                .tag(Tab.chat)

                // Tab 2: Models (right)
                ModelsTabView { pickerModel in
                    selectModelAndChat(pickerModel)
                }
                .tabItem {
                    Label("Models", systemImage: "square.grid.2x2")
                }
                .tag(Tab.models)
            }
            .tint(accent)
            .task {
                await container.downloadService.setModelContext(modelContext)
            }
            .onAppear {
                consumeGuidedOnboarding()
            }
            .onAppear { configureTabBarAppearance() }
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
    }

    private func selectModelAndChat(_ pickerModel: PickerModel) {
        container.selectedModel = pickerModel.toSelectedModel()
        selectedTab = .chat
    }

    private func consumeGuidedOnboarding() {
        guard !guidedOnboardingModelId.isEmpty else { return }
        let repoId = guidedOnboardingModelId
        guidedOnboardingModelId = ""
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
            // Non-fatal
        }
    }

    private func configureTabBarAppearance() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color(hex: "#0D0C18").opacity(0.95))
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

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
