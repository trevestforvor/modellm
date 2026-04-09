import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .browse

    enum Tab { case browse, library, chat }

    private let accent        = Color(hex: "#8B7CF0")
    private let unselected    = Color(hex: "#6B6980")
    private let tabBarSurface = Color(hex: "#0D0C18")

    var body: some View {
        TabView(selection: $selectedTab) {
            BrowseView()
                .tabItem {
                    Label("Browse", systemImage: "square.grid.2x2")
                }
                .tag(Tab.browse)

            libraryPlaceholder
                .tabItem {
                    Label("Library", systemImage: "tray.full")
                }
                .tag(Tab.library)

            chatPlaceholder
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.fill")
                }
                .tag(Tab.chat)
        }
        .tint(accent)
        // Toolbar appearance for dark tab bar
        .onAppear { configureTabBarAppearance() }
    }

    private var libraryPlaceholder: some View {
        ZStack {
            Color(hex: "#0F0E1A").ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "tray.full")
                    .font(.largeTitle)
                    .foregroundStyle(Color(hex: "#6B6980"))
                Text("Library")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "#9896B0"))
                Text("Download models to see them here")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "#6B6980"))
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
        .environment(AppContainer())
}
