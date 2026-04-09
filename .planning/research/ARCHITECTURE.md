# Architecture Research

**Domain:** On-device iOS LLM runner with Hugging Face integration
**Researched:** 2026-04-08
**Confidence:** MEDIUM (architecture patterns well-established; specific component wiring based on training + verified patterns)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          UI Layer (SwiftUI)                          │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────────────┐  │
│  │  ModelBrowser│  │  ModelLibrary  │  │       ChatView           │  │
│  │  (HF search) │  │ (local models) │  │  (inference + streaming) │  │
│  └──────┬───────┘  └───────┬───────┘  └────────────┬─────────────┘  │
│         │                  │                        │                │
├─────────┴──────────────────┴────────────────────────┴────────────────┤
│                        ViewModel / State Layer                        │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │
│  │  BrowseViewModel │  │  LibraryViewModel │  │  ChatViewModel   │   │
│  └──────┬───────────┘  └────────┬──────────┘  └────────┬─────────┘  │
│         │                       │                       │            │
├─────────┴───────────────────────┴───────────────────────┴────────────┤
│                          Service Layer                                │
│  ┌─────────────────┐  ┌──────────────────┐  ┌──────────────────┐    │
│  │  HFAPIService   │  │  DownloadService  │  │  InferenceService│    │
│  │  (search/meta)  │  │  (URLSession BG)  │  │  (llama.cpp)     │    │
│  └────────┬────────┘  └────────┬──────────┘  └────────┬─────────┘   │
│           │                    │                       │             │
├───────────┴────────────────────┴───────────────────────┴─────────────┤
│                     Cross-Cutting Services                            │
│  ┌──────────────────────┐  ┌────────────────────────────────────┐    │
│  │  DeviceCapabilityService│  │  CompatibilityEngine            │    │
│  │  (RAM/chip/storage)  │  │  (hard limits + soft signals)      │    │
│  └──────────────────────┘  └────────────────────────────────────┘    │
├──────────────────────────────────────────────────────────────────────┤
│                          Data Layer                                   │
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────────────┐  │
│  │  ModelMetadata │  │  ModelFileStore  │  │  ConversationStore   │  │
│  │  (SwiftData)   │  │  (FileManager)   │  │  (in-memory/SwiftData│  │
│  └────────────────┘  └─────────────────┘  └──────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘

External:
  ┌──────────────────┐       ┌────────────────────────────┐
  │  Hugging Face    │       │  llama.cpp XCFramework      │
  │  Hub API (REST)  │       │  (Metal/ANE acceleration)   │
  └──────────────────┘       └────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| ModelBrowserView | HF search UI, compatibility badges, download trigger | SwiftUI List + async search |
| ModelLibraryView | Manage downloaded models (view, delete, load) | SwiftUI List + FileManager queries |
| ChatView | Streaming token display, message history | SwiftUI ScrollView + AsyncSequence |
| BrowseViewModel | HF search state, filter logic, pagination | @Observable class |
| LibraryViewModel | Downloaded model list, storage stats | @Observable class |
| ChatViewModel | Active session, message array, streaming state | @Observable class |
| HFAPIService | Hugging Face Hub REST calls (search, metadata, file listing) | URLSession + Codable models |
| DownloadService | Background URLSession downloads, progress tracking, resume | URLSessionDownloadTask + .backgroundConfiguration |
| InferenceService | llama.cpp lifecycle: load model, create context, run inference | Swift wrapper over llama.cpp C API / XCFramework |
| DeviceCapabilityService | Detect RAM, chip family, free storage, OS version | ProcessInfo + sysctlbyname + FileManager |
| CompatibilityEngine | Given model metadata + device specs → hard/soft verdict | Pure Swift logic layer, no I/O |
| ModelMetadataStore | Persist HF metadata + local state for downloaded models | SwiftData |
| ModelFileStore | Manage GGUF files on disk, enforce storage quota | FileManager under app's Documents directory |
| ConversationStore | Message history for active chat | In-memory (v1), optionally SwiftData |

## Recommended Project Structure

```
ModelRunner/
├── App/
│   ├── ModelRunnerApp.swift        # App entry, dependency injection root
│   └── AppContainer.swift          # Service instantiation / DI
├── Features/
│   ├── Browse/
│   │   ├── BrowseView.swift
│   │   ├── BrowseViewModel.swift
│   │   └── ModelRowView.swift      # Compatibility badge + download button
│   ├── Library/
│   │   ├── LibraryView.swift
│   │   ├── LibraryViewModel.swift
│   │   └── ModelDetailView.swift
│   └── Chat/
│       ├── ChatView.swift
│       ├── ChatViewModel.swift
│       └── MessageBubble.swift
├── Services/
│   ├── HuggingFace/
│   │   ├── HFAPIService.swift       # REST client
│   │   ├── HFModels.swift           # Codable DTOs (HFModel, HFFile, etc.)
│   │   └── HFEndpoints.swift        # URL construction
│   ├── Download/
│   │   ├── DownloadService.swift    # URLSession background downloads
│   │   └── DownloadProgress.swift   # Progress tracking model
│   ├── Inference/
│   │   ├── InferenceService.swift   # llama.cpp wrapper
│   │   ├── InferenceSession.swift   # Per-conversation context
│   │   └── TokenStream.swift        # AsyncSequence over token callbacks
│   └── Device/
│       ├── DeviceCapabilityService.swift
│       └── CompatibilityEngine.swift
├── Data/
│   ├── Models/
│   │   ├── LocalModel.swift         # SwiftData model entity
│   │   └── Conversation.swift       # SwiftData (or in-memory)
│   └── Stores/
│       ├── ModelMetadataStore.swift
│       └── ModelFileStore.swift
└── Shared/
    ├── Extensions/
    ├── Components/           # Reusable UI (badges, progress bars)
    └── Constants.swift
```

### Structure Rationale

- **Features/:** Each screen owns its view + view model. No cross-feature view sharing (browse/library/chat are independent flows).
- **Services/:** Stateful long-lived objects injected via the App container. Never instantiated inside views.
- **Data/:** Persistence separated from service logic. SwiftData models only live here — services hold no @Model objects.
- **Shared/:** Pure UI components and extensions; no business logic.

## Architectural Patterns

### Pattern 1: Service Injection via Environment

**What:** Services (HFAPIService, DownloadService, InferenceService) are instantiated once at app root and passed into SwiftUI views via `.environment()`, not created inside views.
**When to use:** All services. Especially critical for InferenceService, which holds expensive llama.cpp state.
**Trade-offs:** Slightly more boilerplate at app root; prevents duplicate context allocation, enables testability.

```swift
// AppContainer.swift
@MainActor class AppContainer: ObservableObject {
    let hfAPI = HFAPIService()
    let downloads = DownloadService()
    let inference = InferenceService()
    let device = DeviceCapabilityService()
    lazy var compatibility = CompatibilityEngine(device: device)
}

// ModelRunnerApp.swift
@main struct ModelRunnerApp: App {
    @StateObject private var container = AppContainer()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
        }
    }
}
```

### Pattern 2: AsyncSequence for Token Streaming

**What:** InferenceService exposes an `AsyncThrowingStream<String, Error>` that emits tokens as llama.cpp generates them. ChatViewModel iterates with `for await token in stream` on a background task.
**When to use:** All inference output. Never buffer and return the full string.
**Trade-offs:** Requires llama.cpp callback bridging; pays off immediately in perceived responsiveness.

```swift
// InferenceService.swift
func generate(prompt: String, context: InferenceContext) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task.detached {
            // llama.cpp token callback → continuation.yield(token)
        }
    }
}
```

### Pattern 3: Compatibility as a Pure Value Transform

**What:** CompatibilityEngine is a pure function: `(ModelMetadata, DeviceSpecs) -> CompatibilityResult`. No I/O, no async.
**When to use:** Called at browse time to annotate each HF result before display.
**Trade-offs:** Easy to test exhaustively. Hard limits and soft signals are expressed as enum cases, not magic strings.

```swift
enum CompatibilityResult {
    case compatible(estimatedSpeed: SpeedTier)
    case marginal(warning: String)           // will run slowly
    case incompatible(reason: IncompatibilityReason)  // cannot run
}
```

### Pattern 4: Background URLSession for Downloads

**What:** DownloadService uses `URLSession(configuration: .background(withIdentifier:))` so downloads survive app backgrounding. Progress delivered via delegate, persisted to SwiftData.
**When to use:** All model file downloads. These are 1–10GB files — foreground session would be wrong.
**Trade-offs:** More complex delegate handling; required for reliable large-file downloads on iOS.

## Data Flow

### Model Discovery Flow

```
User types search query
    ↓
BrowseViewModel.search(query)
    ↓
HFAPIService.searchModels(query, filters: .gguf)  →  HF Hub API
    ↓
[HFModel] response (metadata: size, quant, param count)
    ↓
CompatibilityEngine.evaluate(model, deviceSpecs)
    ↓
[AnnotatedModel] with CompatibilityResult
    ↓
BrowseView renders rows with compatibility badges
```

### Download Flow

```
User taps "Download" on compatible model
    ↓
DownloadService.startDownload(fileURL, modelId)
    ↓ URLSession background task created
    ↓ Progress updates → DownloadService publishes progress
    ↓
LibraryViewModel receives progress update (combine/observation)
    ↓ On completion:
ModelFileStore.register(localURL, modelId)
ModelMetadataStore.markDownloaded(modelId)
    ↓
LibraryView updates to show model as available
```

### Inference Flow

```
User sends message
    ↓
ChatViewModel.send(text)
    ↓ (if no active session) InferenceService.loadModel(localURL) — expensive, async
    ↓
InferenceService.generate(prompt, context) → AsyncThrowingStream<String>
    ↓
ChatViewModel iterates stream, appends tokens to message
    ↓
ChatView re-renders incrementally via @Observable
```

### State Management

```
@Observable ViewModels own screen-local state
Services own cross-screen state (active download, loaded model)
SwiftData owns persistent state (downloaded model list, metadata)
FileManager owns binary state (GGUF files on disk)

No global state store — services are the single source of truth per domain
```

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| HF Hub REST API | URLSession + Codable DTOs | Rate-limited; cache search results. GGUF files filterable by `?search=&library=gguf` |
| HF Hub file downloads | Background URLSession download task | Direct CDN URLs from file listing endpoint |
| llama.cpp | Swift wrapper over C API (XCFramework via SPM) | One context active at a time; context creation is slow (seconds), keep resident |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| HFAPIService ↔ CompatibilityEngine | Synchronous — engine is a pure function called after API response | No coupling; engine only needs DeviceSpecs + ModelMetadata |
| DownloadService ↔ ModelFileStore | Callback on completion — DownloadService calls FileStore.register() | Keeps file management out of download logic |
| InferenceService ↔ ChatViewModel | AsyncThrowingStream | ViewModel never touches llama.cpp directly |
| DeviceCapabilityService ↔ CompatibilityEngine | Injected at startup, read-only snapshot | Device specs don't change mid-session |

## Build Order (Phase Dependencies)

Components must be built in this order due to hard dependencies:

```
1. DeviceCapabilityService          (no deps — pure sysctlbyname/ProcessInfo)
2. CompatibilityEngine              (needs DeviceCapabilityService output shape)
3. HFAPIService + HFModels DTOs     (no deps — pure networking)
4. ModelFileStore + SwiftData schema (no deps — pure persistence)
5. DownloadService                  (needs ModelFileStore for completion registration)
6. InferenceService                 (needs ModelFileStore to resolve local GGUF path)
7. Browse feature (View + ViewModel) (needs HFAPIService + CompatibilityEngine)
8. Library feature (View + ViewModel)(needs ModelFileStore + DownloadService)
9. Chat feature (View + ViewModel)  (needs InferenceService + ConversationStore)
```

Rationale: Services 1–6 are pure infrastructure with no UI. Blocking on infra before features prevents the ViewModel layer from papering over missing services with mocks that become tech debt.

## Anti-Patterns

### Anti-Pattern 1: Creating llama.cpp Context Per Message

**What people do:** Allocate a new llama context for every chat session or message.
**Why it's wrong:** Context creation takes several seconds and allocates the KV cache — rebuilding it per message destroys UX and wastes memory.
**Do this instead:** Keep one InferenceSession resident per loaded model; tear it down only when the user switches models.

### Anti-Pattern 2: Foreground URLSession for Model Downloads

**What people do:** Use a standard URLSession to download GGUF files inline.
**Why it's wrong:** iOS suspends foreground sessions when the app backgrounds. A 5GB download interrupted at 90% restarts from zero.
**Do this instead:** Always use `URLSession(configuration: .background(...))` with a stable identifier. iOS resumes the download even after app termination.

### Anti-Pattern 3: Storing GGUF Files in Caches Directory

**What people do:** Save model files to `NSCachesDirectory` for convenience.
**Why it's wrong:** iOS can purge the Caches directory under storage pressure without warning. The user's downloaded model disappears.
**Do this instead:** Store GGUF files in `NSDocumentDirectory`. Register them in SwiftData so the app can reconcile what's on disk vs. what it knows about.

### Anti-Pattern 4: Fetching Device Specs Inside Views

**What people do:** Call `ProcessInfo.processInfo.physicalMemory` directly in a View or ViewModel.
**Why it's wrong:** Scatters device knowledge; can't mock for tests; inconsistent reads across components.
**Do this instead:** DeviceCapabilityService fetches and caches all specs once at startup. All other components receive it injected.

### Anti-Pattern 5: Running Inference on MainActor

**What people do:** Call llama.cpp token generation on the main thread (easiest path when starting out).
**Why it's wrong:** Inference blocks the run loop; UI freezes between tokens even with streaming.
**Do this instead:** InferenceService runs generation on a detached Task. Token stream yields back to ChatViewModel which marshals to MainActor for UI updates.

## Sources

- [llama.cpp Swift Package Index](https://swiftpackageindex.com/ggml-org/llama.cpp) — MEDIUM confidence
- [swift-huggingface announcement](https://huggingface.co/blog/swift-huggingface) — MEDIUM confidence
- [LLM.swift](https://github.com/eastriverlee/LLM.swift) — MEDIUM confidence (pattern reference)
- [Kuzco Swift package](https://medium.com/@jc_builds/how-to-run-local-ai-models-on-ios-macos-devices-with-kuzco-42173ba376ce) — MEDIUM confidence
- [llama.cpp iOS discussion](https://github.com/ggml-org/llama.cpp/discussions/4423) — MEDIUM confidence
- MVVM + SwiftUI service patterns — HIGH confidence (standard iOS architecture practice)

---
*Architecture research for: iOS on-device LLM runner (ModelRunner)*
*Researched: 2026-04-08*
