# UI Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate 4 tabs (Browse, Library, Chat, Settings) into 2 tabs (Chat + Models) with a card grid for My Models and a list for Browse HF

**Architecture:** New ModelsTabView replaces Browse, Library, and Settings tabs. It contains two sections: MyModelsSection (card grid of downloaded + remote models using ModelPickerViewModel data) and BrowseSection (wraps existing BrowseView HF search). ContentView drops to 2 tabs with Chat on the left.

**Tech Stack:** SwiftUI, SwiftData, existing ModelPickerViewModel + BrowseView/BrowseViewModel

**Spec:** `docs/superpowers/specs/2026-04-12-ui-consolidation-design.md`

---

## File Map

### New Files

| File | Responsibility |
|------|---------------|
| `ModelRunner/Features/Models/ModelsTabView.swift` | Top-level Models tab — scrollable container with MyModelsSection + BrowseSection |
| `ModelRunner/Features/Models/MyModelsSection.swift` | "My Models" section header + 2-column card grid + "Add Server" button |
| `ModelRunner/Features/Models/MyModelCard.swift` | Individual card component — source dot, model name, size, tok/s, capability badge |

### Modified Files

| File | Changes |
|------|---------|
| `ModelRunner/ContentView.swift` | 2 tabs (Chat left, Models right), remove Browse/Library/Settings tabs |
| `ModelRunner/Features/Chat/ChatView.swift` | Add callback for model selection from Models tab (tab switch) |
| `ModelRunner/App/AppContainer.swift` | Add `onModelSelectedFromModelsTab` callback or use existing `selectedModel` |

### Keep (reuse as-is)

| File | Why |
|------|-----|
| `ModelRunner/Features/Browse/BrowseView.swift` | Entire HF browse UI — embedded as BrowseSection in ModelsTabView |
| `ModelRunner/Features/Browse/BrowseViewModel.swift` | HF API + search logic |
| `ModelRunner/Features/Browse/ModelCardView.swift` | HF browse result card (different from MyModelCard) |
| `ModelRunner/Features/Browse/ModelDetailView.swift` | HF model detail screen |
| `ModelRunner/Features/Settings/AddServerView.swift` | "Add Server" sheet |
| `ModelRunner/Features/Settings/ServerDetailView.swift` | Server edit view (from long-press) |
| `ModelRunner/Features/ModelPicker/ModelPickerViewModel.swift` | Data source for My Models grid |
| `ModelRunner/Features/ModelPicker/ModelPickerView.swift` | Still used from Chat toolbar |

---

## Task 1: Create MyModelCard Component

**Files:**
- Create: `ModelRunner/Features/Models/MyModelCard.swift`

- [ ] **Step 1: Create the card view**

```swift
// ModelRunner/Features/Models/MyModelCard.swift
import SwiftUI

/// A rounded rectangle card showing a single model (local or remote) in the My Models grid.
/// Designed for a 2-column LazyVGrid layout.
struct MyModelCard: View {
    let model: PickerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Source indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(sourceDotColor)
                    .frame(width: 8, height: 8)
                Text(sourceLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#6B6980"))
                Spacer()
            }
            .padding(.bottom, 10)

            // Model name
            Text(model.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Size info
            if let serverName = model.serverName {
                Text(serverName)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "#6B6980"))
                    .padding(.top, 3)
            }

            Spacer(minLength: 10)

            // Bottom row: tok/s + badge
            HStack {
                if let tokPerSec = model.tokPerSec {
                    Text(String(format: "%.0f tok/s", tokPerSec))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(hex: "#8B7CF0"))
                } else {
                    Text("— tok/s")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(hex: "#6B6980"))
                }

                Spacer()

                capabilityBadge
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#1A1830"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color(hex: "#302E42"), lineWidth: 1)
                )
        )
        .opacity(model.isOnline ? 1.0 : 0.45)
    }

    // MARK: - Helpers

    private var sourceDotColor: Color {
        if !model.isOnline { return Color(hex: "#ef4444") }
        if case .local = model.source { return Color(hex: "#8B7CF0") }
        return Color(hex: "#22c55e")
    }

    private var sourceLabel: String {
        if case .local = model.source { return "On Device" }
        return model.serverName ?? "Remote"
    }

    @ViewBuilder
    private var capabilityBadge: some View {
        if !model.isOnline {
            Text("offline")
                .font(.system(size: 9))
                .foregroundStyle(Color(hex: "#ef4444"))
        } else if model.supportsThinking {
            badgePill(text: "🧠 think", color: Color(hex: "#8B7CF0"))
        } else if case .local = model.source {
            badgePill(text: "Runs Well", color: Color(hex: "#22c55e"))
        }
    }

    private func badgePill(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.15))
            )
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,id=0B9BD01E-AFFB-466E-856D-D7877FCA161A' 2>&1 | grep -E '(error:|BUILD)' | head -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/Features/Models/MyModelCard.swift
git commit -m "feat: MyModelCard component for 2-column model grid"
```

---

## Task 2: Create MyModelsSection

**Files:**
- Create: `ModelRunner/Features/Models/MyModelsSection.swift`

- [ ] **Step 1: Create the section view**

```swift
// ModelRunner/Features/Models/MyModelsSection.swift
import SwiftUI

/// "My Models" section — 2-column card grid of downloaded + remote models with "+ Add Server" button.
struct MyModelsSection: View {
    let models: [PickerModel]
    let onSelectModel: (PickerModel) -> Void
    let onAddServer: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Text("MY MODELS")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#9896B0"))
                    .tracking(0.5)

                Spacer()

                Button(action: onAddServer) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text("Add Server")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color(hex: "#8B7CF0"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#1A1830"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color(hex: "#302E42"), style: StrokeStyle(lineWidth: 1, dash: [4]))
                            )
                    )
                }
            }

            if models.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "cpu")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(hex: "#302E42"))
                    Text("No models yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(hex: "#9896B0"))
                    Text("Add a remote server or download a model to get started")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#6B6980"))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Card grid
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(models) { model in
                        MyModelCard(model: model)
                            .onTapGesture {
                                if model.isOnline {
                                    onSelectModel(model)
                                }
                            }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,id=0B9BD01E-AFFB-466E-856D-D7877FCA161A' 2>&1 | grep -E '(error:|BUILD)' | head -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/Features/Models/MyModelsSection.swift
git commit -m "feat: MyModelsSection with card grid and Add Server button"
```

---

## Task 3: Create ModelsTabView

**Files:**
- Create: `ModelRunner/Features/Models/ModelsTabView.swift`

- [ ] **Step 1: Create the tab view**

```swift
// ModelRunner/Features/Models/ModelsTabView.swift
import SwiftUI
import SwiftData

/// Unified Models tab — "My Models" card grid + "Browse Hugging Face" section.
/// Replaces the old Browse, Library, and Settings tabs.
struct ModelsTabView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var pickerVM = ModelPickerViewModel()
    @State private var showAddServer = false
    @State private var showSettings = false

    /// Called when user taps a model card — parent (ContentView) switches to Chat tab
    let onSelectModel: (PickerModel) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Section 1: My Models (card grid)
                        MyModelsSection(
                            models: allMyModels,
                            onSelectModel: onSelectModel,
                            onAddServer: { showAddServer = true }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Divider
                        Rectangle()
                            .fill(Color(hex: "#302E42"))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)

                        // Section 2: Browse Hugging Face
                        browseSectionHeader
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
            .task {
                await pickerVM.load(modelContext: modelContext)
            }
            .refreshable {
                await pickerVM.load(modelContext: modelContext)
            }
        }
    }

    /// Flatten all sections from ModelPickerViewModel into a single array for the grid
    private var allMyModels: [PickerModel] {
        pickerVM.sections.flatMap(\.models)
    }

    private var browseSectionHeader: some View {
        Text("BROWSE HUGGING FACE")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(hex: "#9896B0"))
            .tracking(0.5)
    }
}

// MARK: - Embedded Browse (strips NavigationStack since ModelsTabView provides it)

/// Wraps the existing BrowseView content without its own NavigationStack.
/// This avoids nested NavigationStacks while reusing all BrowseView logic.
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
}

/// The browse content — search bar + model list, without NavigationStack wrapper.
private struct BrowseEmbeddedContent: View {
    @Bindable var viewModel: HFBrowseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search bar (inline, not .searchable — avoids NavigationStack requirement)
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

            // Results
            LazyVStack(spacing: 8) {
                if viewModel.isSearching && viewModel.searchResults.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView().tint(Color(hex: "#8B7CF0"))
                        Spacer()
                    }
                    .padding(.top, 20)
                } else if viewModel.searchResults.isEmpty && !viewModel.isSearching {
                    if viewModel.searchQuery.isEmpty {
                        // Show recommendations if available
                        if !viewModel.recommendations.isEmpty {
                            Text("Recommended for Your Device")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                        }
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

// MARK: - Placeholder Settings View

/// Minimal settings sheet — gear icon in Models tab header.
/// Future: inference defaults, theme, about screen.
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
```

- [ ] **Step 2: Create the Models directory**

Run: `mkdir -p ModelRunner/Features/Models`

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,id=0B9BD01E-AFFB-466E-856D-D7877FCA161A' 2>&1 | grep -E '(error:|BUILD)' | head -20`
Expected: BUILD SUCCEEDED (some errors may come from ContentView still referencing old tabs — fixed in Task 4)

- [ ] **Step 4: Commit**

```bash
git add ModelRunner/Features/Models/ModelsTabView.swift
git commit -m "feat: ModelsTabView — unified Models tab with card grid + embedded HF browse"
```

---

## Task 4: Rewire ContentView to 2 Tabs

**Files:**
- Modify: `ModelRunner/ContentView.swift`

- [ ] **Step 1: Replace ContentView with 2-tab layout**

Replace the ENTIRE contents of `ModelRunner/ContentView.swift`:

```swift
// ModelRunner/ContentView.swift
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

    // MARK: - Model Selection from Models Tab

    private func selectModelAndChat(_ pickerModel: PickerModel) {
        container.selectedModel = pickerModel.toSelectedModel()
        selectedTab = .chat
    }

    // MARK: - Guided Onboarding

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

    // MARK: - Appearance

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
```

- [ ] **Step 2: Verify it compiles with zero errors**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,id=0B9BD01E-AFFB-466E-856D-D7877FCA161A' 2>&1 | grep -E '(error:|BUILD)' | head -20`
Expected: BUILD SUCCEEDED with zero errors

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/ContentView.swift
git commit -m "refactor: consolidate to 2-tab layout — Chat (left) + Models (right)"
```

---

## Task 5: Integration Test + Polish

**Files:** None new — verification and fixes

- [ ] **Step 1: Build and verify zero errors**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,id=0B9BD01E-AFFB-466E-856D-D7877FCA161A' 2>&1 | grep -E '(error:|BUILD)' | head -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Run all tests**

Run: `xcodebuild test -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,id=0B9BD01E-AFFB-466E-856D-D7877FCA161A' -only-testing:ModelRunnerTests 2>&1 | grep -E '(Test Case.*pass|Test Case.*FAIL|Executed|BUILD)' | head -30`
Expected: All new + existing tests pass (pre-existing HFBrowseViewModelTests failures are known and unrelated)

- [ ] **Step 3: Manual smoke test**

1. Launch app → should open on Chat tab (left)
2. Tap Models tab (right) → should show "My Models" card grid with remote server models
3. Verify "+ Add Server" button appears in section header
4. Tap a model card → should switch to Chat tab with that model loaded
5. Scroll down on Models tab → "Browse Hugging Face" section with search bar
6. Tap gear icon → Settings sheet appears
7. Verify old Browse, Library, Settings tabs are gone

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: integration fixes from UI consolidation smoke test"
```
