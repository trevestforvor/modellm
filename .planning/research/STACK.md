# Stack Research

**Domain:** On-device iOS LLM runner (Browse → Verify → Download → Infer)
**Researched:** 2026-04-08
**Confidence:** MEDIUM-HIGH (key choices verified via official HF blog + ggml-org SPM index; version numbers from Swift Package Index as of research date)

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

```swift
// Package.swift dependencies
.package(url: "https://github.com/huggingface/swift-huggingface.git", from: "0.8.0"),

// llama.cpp — use binary XCFramework, NOT source Package.swift
// Pin to a specific release build. Update checksum when bumping version.
// Check: https://github.com/ggml-org/llama.cpp/releases
.binaryTarget(
    name: "LlamaFramework",
    url: "https://github.com/ggml-org/llama.cpp/releases/download/b5046/llama-b5046-xcframework.zip",
    checksum: "c19be78b5f00d8d29a25da41042cb7afa094cbf6280a225abe614b03b20029ab"
)
```

```
// Xcode build setting required for llama.cpp Swift/C++ interop
OTHER_SWIFT_FLAGS = -cxx-interoperability-mode=default
```

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

**If the user has iOS 17+ device (target baseline):**
- Use `@Observable` macro + SwiftData for model library persistence
- Use `AsyncStream` for streaming token output to the chat UI
- Because iOS 17 `@Observable` eliminates the `@Published` / `ObservableObject` overhead and is significantly cleaner for streaming

**If device RAM is less than 4GB (iPhone 12 and earlier):**
- Offer only Q2_K and Q3_K_S quantized models
- Hard-filter anything requiring >2.5GB at load time
- Because Q4_K_M (the recommended mobile baseline) requires ~3-4GB for a 3B model; sub-4GB devices will OOM or swap aggressively

**If model file exceeds device free storage by less than 20%:**
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

This is a custom module, not a third-party library. Use these system APIs:

```swift
// Physical RAM
ProcessInfo.processInfo.physicalMemory  // UInt64, bytes

// Chip identifier (maps to A-series generation)
sysctlbyname("hw.machine")  // e.g. "iPhone16,1" → iPhone 15 Pro → A17 Pro

// Available storage
URL.volumeAvailableCapacityForImportantUsage  // URLResourceKey, async

// OS version (for Metal feature set gating)
ProcessInfo.processInfo.operatingSystemVersion
```

Map `hw.machine` identifiers to RAM/chip tier in a local lookup table (maintained in-app). This is more reliable than any third-party device detection library, all of which have stale lookup tables.

## Sources

- https://huggingface.co/blog/swift-huggingface — swift-huggingface 0.8.0 announcement, features, installation (HIGH confidence)
- https://swiftpackageindex.com/ggml-org/llama.cpp — current SPM compatibility, iOS 14+ support (HIGH confidence)
- https://github.com/ggml-org/llama.cpp/releases — XCFramework release artifacts and checksums (HIGH confidence)
- https://github.com/StanfordSpezi/SpeziLLM — SpeziLLM as alternative Swift wrapper (MEDIUM confidence)
- https://enclaveai.app/blog/2025/05/07/huggingface-gguf-search-enclave-ios/ — Real-world iOS GGUF + HF integration patterns (MEDIUM confidence — blog, not official)
- https://enclaveai.app/blog/2025/11/12/practical-quantization-guide-iphone-mac-gguf/ — Quantization tiers for iPhone RAM (MEDIUM confidence)
- https://developer.apple.com/documentation/kernel/1387446-sysctlbyname — sysctlbyname device detection (HIGH confidence)
- https://github.com/ggml-org/llama.cpp/issues/10371 — Known Objective-C++ compilation issues with source SPM target (HIGH confidence — confirms avoiding source target)

---
*Stack research for: ModelRunner — on-device iOS LLM runner*
*Researched: 2026-04-08*
