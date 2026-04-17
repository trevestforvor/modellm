import SwiftUI

struct BrowseView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: HFBrowseViewModel?

    private let meshBase      = Color(hex: "#0D0C18")
    private let secondaryText = Color(hex: "#9896B0")
    private let accent        = Color(hex: "#4D6CF2")

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
                            .font(.appSubheadline)
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

    private var meshBackground: some View {
        AppBackground()
    }
}

// MARK: - Browse Content (requires initialized viewModel)

private struct BrowseContentView: View {
    @Bindable var viewModel: HFBrowseViewModel
    let container: AppContainer

    private let primaryText   = Color(hex: "#EDEDF4")
    private let secondaryText = Color(hex: "#9896B0")
    private let tertiaryText  = Color(hex: "#6B6980")
    private let accent        = Color(hex: "#4D6CF2")

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if viewModel.searchQuery.isEmpty {
                            if !viewModel.recommendations.isEmpty {
                                recommendationsSection
                            }
                            allModelsSection
                        } else {
                            searchResultsSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .scrollContentBackground(.hidden)
            .toolbarBackground(.hidden, for: .navigationBar)
            .searchable(text: $viewModel.searchQuery, prompt: "Search models")
            .navigationTitle("Browse")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: AnnotatedModel.self) { model in
                ModelDetailView(model: model)
            }
        }
    }

    // MARK: Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recommendationsHeader)
                .font(.appTitle)
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
                .font(.appTitle)
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
                if viewModel.hasMoreResults && !viewModel.isLoadingNextPage && !viewModel.didEncounterEmptyNextPage {
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
                .font(.iconXL)
                .foregroundStyle(tertiaryText)
            Text("Couldn't load models")
                .font(.appHeadline)
                .foregroundStyle(primaryText)
            Text("Check your connection and try again.")
                .font(.appBody)
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
                .font(.iconXL)
                .foregroundStyle(tertiaryText)
            Text("No models found")
                .font(.appHeadline)
                .foregroundStyle(primaryText)
            Text("Try a different search term or browse all models.")
                .font(.appBody)
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

// MARK: - Mesh Background (uses shared AppBackground)

private struct BrowseMeshBackground: View {
    var body: some View {
        AppBackground()
    }
}

#Preview {
    BrowseView()
        .environment(AppContainer.shared)
}
