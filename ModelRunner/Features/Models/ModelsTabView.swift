import SwiftUI
import SwiftData

struct ModelsTabView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var pickerVM = ModelPickerViewModel()
    @State private var showAddServer = false
    @State private var showSettings = false
    @State private var showLibrary = false

    let onSelectModel: (PickerModel) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        MyModelsSection(
                            models: allMyModels,
                            onSelectModel: onSelectModel,
                            onAddServer: { showAddServer = true }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        if hasDownloadedModels {
                            Button {
                                showLibrary = true
                            } label: {
                                HStack {
                                    Image(systemName: "internaldrive")
                                        .font(.system(size: 14))
                                    Text("Manage Downloads")
                                        .font(.system(size: 13))
                                }
                                .foregroundStyle(Color(hex: "#9896B0"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }

                        Rectangle()
                            .fill(Color(hex: "#302E42"))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)

                        SpeechSpikeView()
                            .padding(.bottom, 8)

                        Rectangle()
                            .fill(Color(hex: "#302E42"))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)

                        Text("BROWSE HUGGING FACE")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "#9896B0"))
                            .tracking(0.5)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)

                        BrowseEmbeddedView(container: container)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Models")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(Color(hex: "#9896B0"))
                    }
                }
            }
            .sheet(isPresented: $showAddServer) {
                NavigationStack {
                    AddServerView()
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .sheet(isPresented: $showLibrary) {
                NavigationStack {
                    LibraryView()
                }
            }
            .task {
                await pickerVM.load(modelContext: modelContext)
            }
            .refreshable {
                await pickerVM.load(modelContext: modelContext)
            }
        }
    }

    private var allMyModels: [PickerModel] {
        pickerVM.sections.flatMap(\.models)
    }

    private var hasDownloadedModels: Bool {
        pickerVM.sections.contains { $0.id == "local" && !$0.models.isEmpty }
    }
}

// MARK: - Embedded Browse (no own NavigationStack)

private struct BrowseEmbeddedView: View {
    let container: AppContainer
    @State private var viewModel: HFBrowseViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                BrowseEmbeddedContent(viewModel: vm)
            } else {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(Color(hex: "#8B7CF0"))
                    Spacer()
                }
                .padding(.top, 20)
            }
        }
        .onAppear {
            initViewModelIfNeeded()
        }
        .onChange(of: container.compatibilityEngine != nil) { _, ready in
            if ready { initViewModelIfNeeded() }
        }
    }

    private func initViewModelIfNeeded() {
        guard viewModel == nil, let engine = container.compatibilityEngine else { return }
        let vm = HFBrowseViewModel(hfAPI: container.hfAPIService, compatibilityEngine: engine)
        viewModel = vm
        Task { await vm.loadInitialData() }
    }
}

private struct BrowseEmbeddedContent: View {
    @Bindable var viewModel: HFBrowseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Inline search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color(hex: "#6B6980"))
                    .font(.system(size: 14))
                TextField("Search GGUF models...", text: $viewModel.searchQuery)
                    .foregroundStyle(.white)
                    .font(.system(size: 14))
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color(hex: "#6B6980"))
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#1A1830"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(hex: "#302E42"), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Results — use VStack (not LazyVStack) to avoid nested lazy layout thrashing
            VStack(spacing: 8) {
                if viewModel.isSearching && viewModel.searchResults.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView().tint(Color(hex: "#8B7CF0"))
                        Spacer()
                    }
                    .padding(.top, 20)
                } else if viewModel.searchResults.isEmpty && !viewModel.isSearching {
                    if viewModel.searchQuery.isEmpty && !viewModel.recommendations.isEmpty {
                        Text("Recommended for Your Device")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)

                        ForEach(viewModel.recommendations) { model in
                            NavigationLink(value: model) {
                                ModelCardView(model: model)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                    }
                } else {
                    ForEach(viewModel.searchResults) { model in
                        NavigationLink(value: model) {
                            ModelCardView(model: model)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }

                    if viewModel.hasMoreResults {
                        HStack {
                            Spacer()
                            ProgressView().tint(Color(hex: "#8B7CF0"))
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .onAppear {
                            Task { await viewModel.loadNextPage() }
                        }
                    }
                }
            }
        }
        .navigationDestination(for: AnnotatedModel.self) { model in
            ModelDetailView(model: model)
        }
    }
}

// MARK: - Settings Sheet

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Inference Defaults") {
                Text("Temperature, Top-P, System Prompt")
                    .foregroundStyle(Color(hex: "#6B6980"))
            }
            .listRowBackground(Color(hex: "#1A1830"))

            Section("About") {
                LabeledContent("Version") {
                    Text("1.0.0")
                        .foregroundStyle(Color(hex: "#6B6980"))
                }
            }
            .listRowBackground(Color(hex: "#1A1830"))
        }
        .scrollContentBackground(.hidden)
        .background(Color(hex: "#0D0C18"))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(Color(hex: "#8B7CF0"))
            }
        }
    }
}
