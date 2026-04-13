import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ChatViewModel?
    @State private var inputText = ""
    @State private var showSettings = false
    @State private var showModelPicker = false

    /// Active model — set by ContentView from Library active model selection.
    /// Phase 4: passed from ContentView; Phase 5 wires persistent selection.
    var activeModelURL: URL?
    var activeModelName: String = "No Model"
    var activeModelQuant: String = ""

    var body: some View {
        ZStack {
            // MeshGradient background — same dark violet gradient used across the app
            AppBackground()

            if let vm = viewModel {
                chatContent(vm: vm)
            } else {
                noModelPrompt
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    showModelPicker = true
                } label: {
                    VStack(spacing: 2) {
                        Text("Chat")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                        if let selected = container.selectedModel {
                            Text(selected.displayName)
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "#6B6980"))
                        } else if !activeModelName.isEmpty && activeModelName != "No Model" {
                            Text("\(activeModelName) · \(activeModelQuant)")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "#6B6980"))
                        }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    startNewChat()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(hex: "#9896B0"))
                }
                .disabled(viewModel == nil)
            }
        }
        .sheet(isPresented: $showSettings) {
            // Pass the SwiftData DownloadedModel so ChatSettingsView writes temperature,
            // topP, and systemPrompt directly to SwiftData (per-model settings, D-10/D-11).
            if let model = activeModel(from: container) {
                ChatSettingsView(model: model)
            }
        }
        .sheet(isPresented: $showModelPicker) {
            ModelPickerView { pickerModel in
                selectModel(pickerModel)
            }
        }
        .task(id: activeModelURL) {
            await setupViewModel()
        }
    }

    // MARK: - Chat Content

    @ViewBuilder
    private func chatContent(vm: ChatViewModel) -> some View {
        VStack(spacing: 0) {
            switch vm.loadingState {
            case .loading:
                Spacer()
                ChatLoadingView(
                    modelName: activeModelName,
                    quantization: activeModelQuant,
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
                // ZStack allows history overlay to replace chat bubble area with animation
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

            // Input bar — always rendered; disabled when model not ready
            // Clock button at leading edge toggles conversation history
            ChatInputBar(
                text: $inputText,
                isGenerating: vm.isGenerating,
                isModelLoaded: vm.loadingState == .ready,
                onSend: {
                    vm.send(text: inputText)
                    inputText = ""
                },
                onStop: { vm.stop() },
                onToggleHistory: { vm.showingHistory.toggle() },
                enableThinking: Binding(
                    get: { vm.enableThinking },
                    set: { vm.enableThinking = $0 }
                )
            )
        }
        .onAppear {
            vm.configure(modelContext: modelContext)
            if let activeModel = activeModel(from: container) {
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
                            tokensPerSecond: message.isStreaming ? vm.tokensPerSecond : 0,
                            isGenerating: vm.isGenerating && message.isStreaming
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            // Auto-scroll to latest message as tokens stream in
            .onChange(of: vm.messages.count) { _, _ in
                if let last = vm.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var noModelPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: "#302E42"))
            Text("No model selected")
                .font(.headline)
                .foregroundStyle(Color(hex: "#9896B0"))
            Text("Tap \"Chat\" above to pick a model, or add a server in Settings")
                .font(.subheadline)
                .foregroundStyle(Color(hex: "#6B6980"))
                .multilineTextAlignment(.center)

            Button {
                showModelPicker = true
            } label: {
                Text("Select Model")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#8B7CF0"))
                    )
            }
        }
        .padding()
    }

    // MARK: - Background (shared via AppBackground)

    // MARK: - Helpers

    /// Resolve active DownloadedModel from AppContainer for persistence wiring.
    /// Phase 5 wires Library selection; for now we look up by activeModelURL path.
    private func activeModel(from container: AppContainer) -> DownloadedModel? {
        guard let url = activeModelURL else { return nil }
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
        guard let url = activeModelURL else {
            viewModel = nil
            return
        }
        let model = activeModel(from: container)
        let vm = ChatViewModel(
            inferenceService: container.inferenceService,
            inferenceParams: container.inferenceParams(activeModel: model)
        )
        viewModel = vm
        await vm.loadModel(url: url)
    }

    private func selectModel(_ pickerModel: PickerModel) {
        container.selectedModel = pickerModel.toSelectedModel()

        if let backend = container.buildBackend(for: pickerModel, modelContext: modelContext) {
            let vm = ChatViewModel(backend: backend)
            vm.enableThinking = pickerModel.supportsThinking
            vm.configure(modelContext: modelContext)
            let identity = pickerModel.toSelectedModel().modelIdentity
            vm.loadMostRecentConversation(forIdentity: identity, modelContext: modelContext)
            if vm.activeConversation == nil {
                vm.startNewConversation(for: pickerModel.toSelectedModel())
            }
            viewModel = vm
        }
    }

    private func startNewChat() {
        guard let vm = viewModel else { return }

        if let selected = container.selectedModel {
            vm.startNewConversation(for: selected)
        } else if let model = activeModel(from: container) {
            vm.startNewConversation(for: model)
        }

        inputText = ""
    }
}
