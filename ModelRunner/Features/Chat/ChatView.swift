import SwiftUI

struct ChatView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: ChatViewModel?
    @State private var inputText = ""
    @State private var showSettings = false

    /// Active model — set by ContentView from Library active model selection.
    /// Phase 4: passed from ContentView; Phase 5 wires persistent selection.
    var activeModelURL: URL?
    var activeModelName: String = "No Model"
    var activeModelQuant: String = ""

    var body: some View {
        ZStack {
            // MeshGradient background — same dark violet gradient used across the app
            chatMeshGradient

            if let vm = viewModel {
                chatContent(vm: vm)
            } else {
                noModelPrompt
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Chat")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    if !activeModelName.isEmpty && activeModelName != "No Model" {
                        Text("\(activeModelName) · \(activeModelQuant)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#6B6980"))
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                        .foregroundStyle(Color(hex: "#9896B0"))
                }
                .disabled(viewModel == nil)
            }
        }
        .sheet(isPresented: $showSettings) {
            if let vm = viewModel {
                ChatSettingsView(settings: Binding(
                    get: { vm.settings },
                    set: { vm.settings = $0 }
                ))
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
                messageList(vm: vm)
            }

            // Input bar — always rendered; disabled when model not ready
            ChatInputBar(
                text: $inputText,
                isGenerating: vm.isGenerating,
                isModelLoaded: vm.loadingState == .ready,
                onSend: {
                    vm.send(text: inputText)
                    inputText = ""
                },
                onStop: { vm.stop() }
            )
        }
    }

    private func messageList(vm: ChatViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(vm.messages) { message in
                        ChatBubbleView(
                            message: message,
                            tokensPerSecond: vm.tokensPerSecond,
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
            Text("Go to Library and tap a model to load it")
                .font(.subheadline)
                .foregroundStyle(Color(hex: "#6B6980"))
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - MeshGradient background

    private var chatMeshGradient: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: [
                Color(hex: "#0D0C18"), Color(hex: "#141230"), Color(hex: "#0D0C18"),
                Color(hex: "#1A1040"), Color(hex: "#221850"), Color(hex: "#180E35"),
                Color(hex: "#0D0C18"), Color(hex: "#120B2E"), Color(hex: "#0D0C18")
            ]
        )
        .ignoresSafeArea()
    }

    // MARK: - Setup

    private func setupViewModel() async {
        guard let url = activeModelURL else {
            viewModel = nil
            return
        }
        let vm = ChatViewModel(
            inferenceService: container.inferenceService,
            inferenceParams: container.inferenceParams()
        )
        viewModel = vm
        await vm.loadModel(url: url)
    }
}
