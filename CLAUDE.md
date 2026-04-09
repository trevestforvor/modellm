<!-- GSD:project-start source:PROJECT.md -->
## Project

**ModelRunner**

An iOS app that lets users browse Hugging Face models, verify compatibility with their specific device, download compatible models, and run inference locally on-device. Think LM Studio for iPhone — the key differentiator is intelligent device-aware filtering so users never download a model that won't work (or will barely work) on their hardware.

**Core Value:** Device-aware model compatibility verification — users see at a glance what will run well, what will run slowly, and what won't run at all on their specific device, before downloading anything.

### Constraints

- **Platform**: iOS (SwiftUI) — iPhone only for v1
- **Inference engine**: llama.cpp Swift bindings — proven iOS support, GGUF format
- **Model source**: Hugging Face Hub API — primary model registry
- **On-device only**: No server-side inference, all processing happens locally
- **Storage**: Must respect device storage limits and allow users to manage downloaded models
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Core Technologies
| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| SwiftUI | iOS 17+ target | UI framework | Native, declarative, no third-party dependency. Async/await + @Observable (iOS 17) makes streaming token output straightforward. |
| llama.cpp (via XCFramework binary target) | b5046+ / latest release | On-device LLM inference | Most mature GGUF inference engine for Apple hardware, ANE/GPU Metal acceleration, active releases. Binary XCFramework target avoids `unsafeFlags` SPM limitation. |
| swift-huggingface | 0.8.0+ | HF Hub API: model search, metadata, file download | Official HF-maintained Swift client. Ground-up rewrite with progress tracking, resume support, Python-compatible cache, and proper authentication via TokenProvider. Replaces hand-rolled URLSession HF calls. |
| Swift Concurrency (async/await + actors) | Swift 5.9+ | Inference loop, download management, device detection | Inference is inherently async; actors prevent data races on the model context. Required for streaming token callbacks. |
### Supporting Libraries
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| StanfordBDHG/llama.cpp (SpeziLLM fork) | latest | Alternative precompiled XCFramework with higher-level Swift API | Use if you want a higher-level Swift wrapper around llama.cpp and are OK taking the Spezi ecosystem dependency. Not recommended for this project — adds Spezi overhead not needed here. |
| swift-transformers (HF) | 1.0+ | Tokenizer support (BPE, SentencePiece) | Only if you need tokenization outside llama.cpp's built-in tokenizer. llama.cpp handles tokenization internally for GGUF models, so this is likely not needed for v1. |
| OSLog / Unified Logging | system | Structured logging for inference timing, download events | Use over `print`. Enables performance profiling in Instruments. |
### Development Tools
| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16+ | Build, sign, profile | Required for Swift/C++ interop flag (`-cxx-interoperability-mode=default`) needed by llama.cpp SPM integration. |
| Instruments (Time Profiler, Allocations) | Inference performance + memory profiling | ANE vs CPU vs GPU dispatch is invisible without profiling; run on physical device only. |
| Swift Package Index | Dependency version tracking | Use to verify current llama.cpp release build number and checksum before pinning. |
| xcodes / Xcode version manager | Maintain specific Xcode version for C++ interop stability | llama.cpp SPM integration is sensitive to Swift toolchain version. |
## Installation
## Alternatives Considered
| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| llama.cpp XCFramework binary target | llama.cpp source Package.swift | Only if you need to patch llama.cpp internals. Source target requires `unsafeFlags` which breaks semantic versioning in SPM and causes downstream build issues. |
| swift-huggingface (official HF) | Hand-rolled URLSession HF API client | Never — swift-huggingface is official, maintained, handles resume and caching correctly. |
| swift-huggingface | swift-transformers HubApi | swift-transformers HubApi is being replaced by swift-huggingface. HF blog explicitly states swift-huggingface will supersede it. |
| URLSession background download (via swift-huggingface) | Third-party download managers (Alamofire, etc.) | Only if you need complex download queue orchestration beyond what URLSession provides. Unnecessary for this scope. |
| Apple MLX / Core ML | llama.cpp | MLX is excellent for Mac, but iOS support is experimental and GGUF model ecosystem is built around llama.cpp. Core ML requires model conversion (not GGUF native). llama.cpp is the right choice for GGUF-first iOS. |
## What NOT to Use
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| llama.cpp source Package.swift (ggml-org/llama.cpp direct SPM) | Requires `unsafeFlags`, breaks semantic versioning, known Objective-C++ compilation failures in Xcode 16+ (March 2025 issues). | Binary XCFramework target via `.binaryTarget` in SPM |
| vijaysharm/Huggingface.Swift | Thin wrapper around inference API only, not the Hub download API. Abandoned-looking, not official HF. | swift-huggingface (official) |
| alexrozanski/llama.swift | Stale fork targeting original LLaMA only. Superseded. | ggml-org/llama.cpp XCFramework |
| LLMFarm (guinmoon) as a library | App-level code, not a clean library. Hard to embed selectively. | Direct llama.cpp XCFramework |
| Core Data for model metadata | Overkill for a flat list of downloaded models with simple metadata. Adds migration complexity. | Swift Data (iOS 17+) — lightweight, native, no migration boilerplate for v1 |
| CloudKit or iCloud sync | Models are multi-gigabyte. Syncing model files is impractical. | Local storage only, explicit user export if needed |
## Stack Patterns by Variant
- Use `@Observable` macro + SwiftData for model library persistence
- Use `AsyncStream` for streaming token output to the chat UI
- Because iOS 17 `@Observable` eliminates the `@Published` / `ObservableObject` overhead and is significantly cleaner for streaming
- Offer only Q2_K and Q3_K_S quantized models
- Hard-filter anything requiring >2.5GB at load time
- Because Q4_K_M (the recommended mobile baseline) requires ~3-4GB for a 3B model; sub-4GB devices will OOM or swap aggressively
- Block download with a hard error, not a warning
- Because partial downloads of GGUF files leave corrupt unusable artifacts that are confusing to users
## Version Compatibility
| Package | Compatible With | Notes |
|---------|-----------------|-------|
| llama.cpp b5046+ XCFramework | Xcode 15.3+, iOS 14+ | iOS 14 minimum per ggml-org Package.swift. Recommend targeting iOS 17 for SwiftData + @Observable. |
| swift-huggingface 0.8.0+ | Swift 5.9+, iOS 15+ | Ground-up rewrite; not backward compatible with older HubApi usage in swift-transformers. |
| Swift/C++ interop (`-cxx-interoperability-mode=default`) | Xcode 15+ (Swift 5.9+) | Required for llama.cpp if using source target. NOT needed for XCFramework binary target — this is a key advantage of the binary approach. |
| SwiftData | iOS 17+ | If targeting iOS 16, fall back to Core Data. Given this is a new app in 2026, iOS 17 baseline is reasonable. |
## Device Capability Detection — No Library Needed
## Sources
- https://huggingface.co/blog/swift-huggingface — swift-huggingface 0.8.0 announcement, features, installation (HIGH confidence)
- https://swiftpackageindex.com/ggml-org/llama.cpp — current SPM compatibility, iOS 14+ support (HIGH confidence)
- https://github.com/ggml-org/llama.cpp/releases — XCFramework release artifacts and checksums (HIGH confidence)
- https://github.com/StanfordSpezi/SpeziLLM — SpeziLLM as alternative Swift wrapper (MEDIUM confidence)
- https://enclaveai.app/blog/2025/05/07/huggingface-gguf-search-enclave-ios/ — Real-world iOS GGUF + HF integration patterns (MEDIUM confidence — blog, not official)
- https://enclaveai.app/blog/2025/11/12/practical-quantization-guide-iphone-mac-gguf/ — Quantization tiers for iPhone RAM (MEDIUM confidence)
- https://developer.apple.com/documentation/kernel/1387446-sysctlbyname — sysctlbyname device detection (HIGH confidence)
- https://github.com/ggml-org/llama.cpp/issues/10371 — Known Objective-C++ compilation issues with source SPM target (HIGH confidence — confirms avoiding source target)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
