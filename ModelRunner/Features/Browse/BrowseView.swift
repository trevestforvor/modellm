import SwiftUI

struct BrowseView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: HFBrowseViewModel?

    private let meshBase      = Color(hex: "#0F0E1A")
    private let secondaryText = Color(hex: "#9896B0")
    private let accent        = Color(hex: "#8B7CF0")

    var body: some View {
        Group {
            if let vm = viewModel {
                BrowseContentView(viewModel: vm, container: container)
            } else {
                // Waiting for compatibilityEngine to initialize
                ZStack {
                    meshBackground
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(accent)
                        Text("Initializing…")
                            .font(.subheadline)
                            .foregroundStyle(secondaryText)
                    }
                }
            }
        }
        .onAppear { initViewModelIfNeeded() }
        .onChange(of: container.compatibilityEngine != nil) { _, _ in
            initViewModelIfNeeded()
        }
    }

    private func initViewModelIfNeeded() {
        guard viewModel == nil, let engine = container.compatibilityEngine else { return }
        let vm = HFBrowseViewModel(hfAPI: container.hfAPIService, compatibilityEngine: engine)
        viewModel = vm
        Task { await vm.loadInitialData() }
    }

    @ViewBuilder
    private var meshBackground: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: [
                    Color(hex: "#172440"), Color(hex: "#0F0E1A"), Color(hex: "#122A32"),
                    Color(hex: "#221942"), Color(hex: "#110F1C"), Color(hex: "#141E3A"),
                    Color(hex: "#0F0E1A"), Color(hex: "#12242C"), Color(hex: "#1C153E")
                ]
            )
            .ignoresSafeArea()
        } else {
            meshBase.ignoresSafeArea()
        }
    }
}

// MARK: - Browse Content (requires initialized viewModel)

private struct BrowseContentView: View {
    @Bindable var viewModel: HFBrowseViewModel
    let container: AppContainer

    private let primaryText   = Color(hex: "#EDEDF4")
    private let secondaryText = Color(hex: "#9896B0")
    private let tertiaryText  = Color(hex: "#6B6980")
    private let accent        = Color(hex: "#8B7CF0")

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if viewModel.searchQuery.isEmpty {
                        // Recommendations section
                        if !viewModel.recommendations.isEmpty {
                            recommendationsSection
                        }
                        // All Models section
                        allModelsSection
                    } else {
                        // Search results
                        searchResultsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(.clear)
            .searchable(text: $viewModel.searchQuery, prompt: "Search models")
            .navigationTitle("Browse")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: AnnotatedModel.self) { model in
                ModelDetailView(model: model)
            }
        }
        .background {
            BrowseMeshBackground()
        }
    }

    // MARK: Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recommendationsHeader)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(primaryText)
                .padding(.top, 20)
                .padding(.bottom, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.recommendations) { model in
                        NavigationLink(value: model) {
                            ModelCardView(model: model)
                                .frame(width: min(UIScreen.main.bounds.width * 0.80, 320))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 4)
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: All Models

    private var allModelsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("All Models")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(primaryText)
                .padding(.top, 8)

            modelList(models: viewModel.searchResults,
                      isLoading: viewModel.isSearching,
                      error: viewModel.searchError)
        }
    }

    // MARK: Search Results

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            modelList(models: viewModel.searchResults,
                      isLoading: viewModel.isSearching,
                      error: viewModel.searchError)
        }
    }

    // MARK: Shared List Builder

    @ViewBuilder
    private func modelList(models: [AnnotatedModel],
                           isLoading: Bool,
                           error: HFBrowseError?) -> some View {
        if isLoading && models.isEmpty {
            // Initial loading state
            HStack { Spacer(); ProgressView().tint(accent); Spacer() }
                .padding(.top, 40)
        } else if let error, models.isEmpty {
            // Error state
            errorView(error: error)
        } else if models.isEmpty && !isLoading {
            // Empty state
            emptyStateView
        } else {
            // Model cards
            LazyVStack(spacing: 8) {
                ForEach(models) { model in
                    NavigationLink(value: model) {
                        ModelCardView(model: model)
                    }
                    .buttonStyle(.plain)
                }

                // Infinite scroll trigger
                if viewModel.hasMoreResults {
                    HStack { Spacer(); ProgressView().tint(accent); Spacer() }
                        .padding(.vertical, 16)
                        .onAppear {
                            Task { await viewModel.loadNextPage() }
                        }
                }
            }
        }
    }

    // MARK: Error State

    private func errorView(error: HFBrowseError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(tertiaryText)
            Text("Couldn't load models")
                .font(.headline)
                .foregroundStyle(primaryText)
            Text("Check your connection and try again.")
                .font(.body)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await viewModel.loadInitialData() }
            }
            .buttonStyle(.bordered)
            .tint(accent)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }

    // MARK: Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(tertiaryText)
            Text("No models found")
                .font(.headline)
                .foregroundStyle(primaryText)
            Text("Try a different search term or browse all models.")
                .font(.body)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
            Button("Browse All Models") {
                viewModel.searchQuery = ""
            }
            .buttonStyle(.bordered)
            .tint(accent)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }

    // MARK: Helpers

    private var recommendationsHeader: String {
        "Recommended for Your Device"
    }
}

// MARK: - Mesh Background (extracted to avoid ViewBuilder complexity)

private struct BrowseMeshBackground: View {
    var body: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: [
                    Color(hex: "#172440"), Color(hex: "#0F0E1A"), Color(hex: "#122A32"),
                    Color(hex: "#221942"), Color(hex: "#110F1C"), Color(hex: "#141E3A"),
                    Color(hex: "#0F0E1A"), Color(hex: "#12242C"), Color(hex: "#1C153E")
                ]
            )
            .ignoresSafeArea()
        } else {
            Color(hex: "#0F0E1A").ignoresSafeArea()
        }
    }
}

#Preview {
    BrowseView()
        .environment(AppContainer())
}
