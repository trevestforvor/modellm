import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.modelrunner", category: "ChatRootView")

/// Single-screen chat root.
/// Replaces the prior two-tab Chat | Models layout. The Models view is now a sheet
/// presented from the toolbar's model-name button. Per-model settings live in the
/// gear sheet (SettingsView), not in a dedicated toolbar button.
struct ChatRootView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ChatViewModel?
    @State private var inputText = ""
    @State private var showSettingsSheet = false
    @State private var showModelsSheet = false

    var body: some View {
        ZStack {
            // MeshGradient background — same dark violet gradient used across the app
            AppBackground()

            if let vm = viewModel {
                chatContent(vm: vm)
            } else if container.activeModelURL != nil || container.selectedModel != nil {
                // Bundled model is loading or selection in flight — show "no model" placeholder
                noModelPrompt
            } else {
                // True empty state — no model selected at all (edge case: user deleted bundled)
                ChatEmptyState(modelName: nil) { showModelsSheet = true }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let vm = viewModel {
                VStack(spacing: 0) {
                    if vm.tokensPerSecond > 0 || vm.streamingMessage?.finalTokPerSec != nil {
                        HStack {
                            ToksPerSecondBadge(
                                tokensPerSecond: vm.tokensPerSecond > 0 ? vm.tokensPerSecond : (vm.messages.last?.finalTokPerSec ?? 0),
                                isGenerating: vm.isGenerating
                            )
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    }

                    ChatInputBar(
                        text: $inputText,
                        isGenerating: vm.isGenerating,
                        isModelLoaded: vm.loadingState == .ready,
                        onSend: {
                            vm.send(text: inputText)
                            inputText = ""
                        },
                        onStop: { vm.stop() },
                        supportsVision: activeDownloadedModel()?.supportsVision ?? false,
                        onAttachFile: { logger.info("attachment tapped: file") },
                        onTakePhoto: { logger.info("attachment tapped: camera") },
                        onAttachPhoto: { logger.info("attachment tapped: photo") },
                        enableThinking: Binding(
                            get: { vm.enableThinking },
                            set: { vm.enableThinking = $0 }
                        )
                    )
                }
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 14) {
                    Button {
                        showSettingsSheet = true
                    } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(Color(hex: "#9896B0"))
                    }
                    .accessibilityLabel("Settings")
                    Button {
                        viewModel?.showingHistory.toggle()
                    } label: {
                        Image(systemName: "bubble.left")
                            .foregroundStyle(Color(hex: "#9896B0"))
                    }
                    .accessibilityLabel("Conversation history")
                    .disabled(viewModel == nil)
                }
            }
            ToolbarItem(placement: .principal) {
                Button {
                    showModelsSheet = true
                } label: {
                    VStack(spacing: 2) {
                        Text(currentModelDisplayName)
                            .font(.title3.weight(.semibold))
                            .fontDesign(.serif)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let subtitle = currentModelSubtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#6B6980"))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: 220)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    startNewChat()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(hex: "#9896B0"))
                }
                .accessibilityLabel("New chat")
                .disabled(viewModel == nil)
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                SettingsView()
                    .environment(container)
            }
        }
        .sheet(isPresented: $showModelsSheet) {
            ModelsTabView(
                onSelectModel: { pickerModel in
                    selectModel(pickerModel)
                    showModelsSheet = false
                },
                onDismiss: { showModelsSheet = false }
            )
            .environment(container)
        }
        .task {
            // Move ContentView's setup work into ChatRootView so the app launches straight here
            await container.downloadService.setModelContext(modelContext)
            BundledModelInstaller.installIfNeeded(modelContext: modelContext)
            // Auto-activate a model on first launch when nothing is selected.
            // The previous flow relied on WelcomeView to set guidedOnboardingModelId;
            // with the single-screen layout the user just expects "open app, chat works."
            autoActivateIfNeeded()
        }
        // Compose key from BOTH selectedModel id AND activeModelURL so the task re-fires
        // when autoActivateIfNeeded resolves the local URL (selectedModel may be restored
        // from UserDefaults while activeModelURL starts nil).
        .task(id: "\(container.selectedModel?.backendID ?? "")|\(container.activeModelURL?.path ?? "")") {
            await setupViewModel()
        }
    }

    // MARK: - Toolbar Title Helpers

    private var currentModelDisplayName: String {
        let raw: String
        if let selected = container.selectedModel {
            raw = selected.displayName
        } else if let name = container.activeModelName, !name.isEmpty {
            raw = name
        } else {
            return "No Model"
        }
        return Self.friendlyModelName(raw)
    }

    /// Produces a human-friendly short name from a verbose model string.
    /// Example: "SmolLM2-360M-Instruct (Bundled) Q4_K_M" → "SmolLM2 360M"
    static func friendlyModelName(_ raw: String) -> String {
        var s = raw
        // Drop parenthetical annotations: "(Bundled)", "(Q4_K_M)", etc.
        if let parenIdx = s.firstIndex(of: "(") {
            s = String(s[..<parenIdx])
        }
        s = s.trimmingCharacters(in: .whitespaces)

        // Strip common trailing descriptors case-insensitively.
        let suffixesToStrip = ["-Instruct", " Instruct", "-Chat", " Chat", "-it"]
        for suffix in suffixesToStrip {
            if let range = s.range(of: suffix, options: [.caseInsensitive, .backwards])
                , range.upperBound == s.endIndex {
                s.removeSubrange(range)
            }
        }

        // Replace remaining dashes with spaces for readability.
        s = s.replacingOccurrences(of: "-", with: " ")
        s = s.replacingOccurrences(of: "  ", with: " ")
        return s.trimmingCharacters(in: .whitespaces)
    }

    private var currentModelSubtitle: String? {
        // Prefer remote-source label when a remote selection is active.
        if let selected = container.selectedModel {
            switch selected.source {
            case .remote: return "Remote"
            case .local: return nil
            }
        }
        // Local fallback: show quantization
        if let q = container.activeModelQuant, !q.isEmpty { return q }
        return nil
    }

    // MARK: - Chat Content

    @ViewBuilder
    private func chatContent(vm: ChatViewModel) -> some View {
        VStack(spacing: 0) {
            switch vm.loadingState {
            case .loading:
                Spacer()
                ChatLoadingView(
                    modelName: container.activeModelName ?? container.selectedModel?.displayName ?? "",
                    quantization: container.activeModelQuant ?? "",
                    sizeDescription: "..."
                )
                Spacer()
            case .failed(let msg):
                Spacer()
                Text("Failed to load model: \(msg)")
                    .foregroundStyle(Color(hex: "#6B6980"))
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            default:
                ZStack(alignment: .bottom) {
                    if vm.showingHistory {
                        ConversationHistoryView(
                            currentModelIdentity: container.selectedModel?.modelIdentity ?? vm.activeConversation?.modelIdentity,
                            onSelect: { conversation in
                                vm.activeConversation = conversation
                                vm.messages = conversation.messages
                                    .sorted { $0.createdAt < $1.createdAt }
                                    .map { ChatMessage(role: $0.role == "user" ? .user : .assistant, content: $0.content) }
                                vm.showingHistory = false
                            },
                            onDismiss: {
                                vm.showingHistory = false
                            },
                            onDelete: { conversation in
                                vm.deleteConversation(conversation)
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        messageList(vm: vm)
                            .transition(.opacity)
                    }
                }
                .animation(.spring(duration: 0.3, bounce: 0.15), value: vm.showingHistory)
            }
        }
        .onAppear {
            vm.configure(modelContext: modelContext)
            if let activeModel = activeDownloadedModel() {
                vm.loadMostRecentConversation(for: activeModel, modelContext: modelContext)
            }
        }
    }

    private func messageList(vm: ChatViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(vm.messages) { message in
                        ChatBubbleView(
                            message: message,
                            tokensPerSecond: 0,
                            isGenerating: false,
                            onFeedback: { kind in vm.toggleFeedback(for: message.id, kind: kind) },
                            onCopy: { vm.copyMessage(message) },
                            onRegenerate: { vm.regenerate(from: message.id) }
                        )
                        .id(message.id)
                    }

                    if let streaming = vm.streamingMessage {
                        ChatBubbleView(
                            message: streaming,
                            tokensPerSecond: 0,
                            isGenerating: true
                        )
                        .id(streaming.id)
                    }

                    Spacer().frame(height: 15)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.messages.count) { _, _ in
                scrollToBottom(proxy: proxy, vm: vm)
            }
            .onChange(of: vm.streamingFlushCount) { _, _ in
                scrollToBottom(proxy: proxy, vm: vm)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, vm: ChatViewModel) {
        let targetID = vm.streamingMessage?.id ?? vm.messages.last?.id
        if let id = targetID {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }

    private var noModelPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: "#302E42"))
            Text("Loading model...")
                .font(.headline)
                .foregroundStyle(Color(hex: "#9896B0"))
            ProgressView()
                .tint(Color(hex: "#7C7BF5"))
        }
        .padding()
    }

    // MARK: - Helpers

    /// First-launch fallback: when the user has no selectedModel and no activeModelURL,
    /// pick the smallest local DownloadedModel (typically the bundled SmolLM2-360M)
    /// and activate it so the chat is immediately usable.
    /// Also restores activeModelURL when a local selectedModel was persisted to UserDefaults
    /// but the runtime-only activeModelURL is nil (which happens after every app restart).
    private func autoActivateIfNeeded() {
        // Remote selection — nothing to do; the .task(id:) builds the remote backend itself.
        if container.selectedModel?.source.isRemote == true { return }
        // If a local model is already fully wired up, nothing to do.
        if container.activeModelURL != nil { return }

        // Case 1: a local SelectedModel was restored from UserDefaults — re-resolve
        // the on-disk path so setupViewModel can build the LocalInferenceBackend.
        if let selected = container.selectedModel, case .local = selected.source {
            let repoId = selected.backendID
            let descriptor = FetchDescriptor<DownloadedModel>(
                predicate: #Predicate { $0.repoId == repoId }
            )
            if let model = try? modelContext.fetch(descriptor).first {
                container.activeModelURL = URL(filePath: model.localPath)
                container.activeModelName = model.displayName
                container.activeModelQuant = model.quantization
                return
            }
            // Selection points at a model we no longer have on disk — fall through
            // and pick a different one below.
        }

        // Case 2: no selection at all — pick the smallest local model.
        let descriptor = FetchDescriptor<DownloadedModel>()
        guard let models = try? modelContext.fetch(descriptor), !models.isEmpty else { return }
        let chosen = models.min(by: { $0.fileSizeBytes < $1.fileSizeBytes }) ?? models[0]
        container.activeModelURL = URL(filePath: chosen.localPath)
        container.activeModelName = chosen.displayName
        container.activeModelQuant = chosen.quantization
        container.selectedModel = SelectedModel(
            backendID: chosen.repoId,
            displayName: chosen.displayName,
            source: .local
        )
    }

    /// Resolve active DownloadedModel from container.activeModelURL for persistence wiring.
    private func activeDownloadedModel() -> DownloadedModel? {
        guard let url = container.activeModelURL else { return nil }
        var descriptor = FetchDescriptor<DownloadedModel>(
            predicate: #Predicate { $0.localPath == url.path }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Setup

    private func setupViewModel() async {
        // Check for remote model selection first
        if let selected = container.selectedModel, selected.source.isRemote {
            let pickerModel = PickerModel(
                id: selected.backendID,
                displayName: selected.displayName,
                source: selected.source,
                serverID: nil,
                serverName: nil,
                tokPerSec: nil,
                isOnline: true,
                thinkingCapability: .none
            )
            if let backend = container.buildBackend(for: pickerModel, modelContext: modelContext) {
                let vm = ChatViewModel(backend: backend)
                vm.configure(modelContext: modelContext)
                vm.loadMostRecentConversation(forIdentity: selected.modelIdentity, modelContext: modelContext)
                viewModel = vm
                return
            }
        }

        // Fall back to local model setup
        guard let url = container.activeModelURL else {
            viewModel = nil
            return
        }
        guard let model = activeDownloadedModel() else {
            viewModel = nil
            return
        }
        _ = url
        let localBackend = container.buildLocalBackend(for: model)
        let vm = ChatViewModel(backend: localBackend)
        vm.configure(modelContext: modelContext)

        let identity = "local:\(model.repoId)"
        vm.loadMostRecentConversation(forIdentity: identity, modelContext: modelContext)
        if vm.activeConversation == nil {
            let selected = SelectedModel(backendID: model.repoId, displayName: model.displayName, source: .local)
            vm.startNewConversation(for: selected)
        }
        viewModel = vm
        await vm.prepareBackend()
    }

    /// Called from ModelsTabView sheet selection. Mirrors the prior ContentView.selectModelAndChat
    /// behavior so this single-screen layout handles both local and remote picks.
    private func selectModel(_ pickerModel: PickerModel) {
        container.selectedModel = pickerModel.toSelectedModel()

        // For local models, wire activeModelURL/Name/Quant so the local backend setup path triggers
        // via the .task(id:) re-fire.
        if case .local = pickerModel.source {
            let repoId = pickerModel.id
            let descriptor = FetchDescriptor<DownloadedModel>(
                predicate: #Predicate { $0.repoId == repoId }
            )
            if let model = try? modelContext.fetch(descriptor).first {
                container.activeModelURL = URL(filePath: model.localPath)
                container.activeModelName = model.displayName
                container.activeModelQuant = model.quantization
            }
        } else {
            // Remote selection — clear local-only state so the .task(id:) re-fires on selection change
            container.activeModelURL = nil
            container.activeModelName = nil
            container.activeModelQuant = nil
        }
    }

    private func startNewChat() {
        guard let vm = viewModel else { return }

        if let selected = container.selectedModel {
            vm.startNewConversation(for: selected)
        } else if let model = activeDownloadedModel() {
            vm.startNewConversation(for: model)
        }

        inputText = ""
    }
}
