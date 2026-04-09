# Project Research Summary

**Project:** ModelRunner — on-device iOS LLM runner
**Domain:** iOS native app: Hugging Face model browser + GGUF downloader + llama.cpp inference
**Researched:** 2026-04-08
**Confidence:** MEDIUM-HIGH

## Executive Summary

ModelRunner is an iOS app that lets users browse Hugging Face for GGUF models, download them to the device, and run inference locally via llama.cpp. Three existing iOS players exist (PocketPal AI, LLMFarm, and desktop-crossover LM Studio) but none performs pre-download compatibility screening — every app lets users download whatever they want and discover failures at runtime. This is the single clearest moat: ModelRunner should block incompatible downloads before they start, show three-tier compatibility ratings ("Runs well / Runs slowly / Won't run"), and give users storage-impact warnings before they commit. Everything else is table stakes parity.

The recommended stack is narrow and justified: SwiftUI + iOS 17 @Observable, llama.cpp via precompiled XCFramework binary target (not source SPM), and the official swift-huggingface 0.8.0+ client. The binary XCFramework approach is non-negotiable — the source SPM target requires `unsafeFlags`, has known Objective-C++ compilation failures in Xcode 16+, and breaks semantic versioning. The architecture follows standard iOS MVVM with three feature modules (Browse, Library, Chat) backed by four services (HFAPIService, DownloadService, InferenceService, DeviceCapabilityService) and a pure-function CompatibilityEngine that sits cross-cutting.

The dominant risks are all memory and threading related: jetsam limits mean available app RAM is ~40% of physical RAM (not total RAM), KV cache grows linearly with context length and will silently OOM mid-conversation if uncapped, Metal cannot be initialized from a background thread so auto-loading a model when a download completes will hard-crash, and background URLSession has non-obvious lifecycle requirements for multi-gigabyte files. All of these are preventable with the right architecture from day one — retrofitting them after the fact is costly, particularly the RAM/compatibility model.

## Key Findings

### Recommended Stack

Use llama.cpp via precompiled XCFramework binary SPM target (not source), swift-huggingface 0.8.0+ for all HF Hub interactions, SwiftUI targeting iOS 17+ for @Observable and SwiftData, and Swift Concurrency throughout. Device capability detection requires no third-party library — `ProcessInfo.processInfo.physicalMemory`, `sysctlbyname("hw.machine")`, and `URL.volumeAvailableCapacityForImportantUsage` cover all needs. Core ML and Apple MLX are wrong choices: MLX iOS support is experimental, and Core ML requires model conversion away from GGUF.

**Core technologies:**
- **llama.cpp XCFramework (b5046+):** On-device GGUF inference with Metal/ANE acceleration — binary target avoids `unsafeFlags` and Xcode 16 C++ interop issues
- **swift-huggingface 0.8.0+:** Official HF Hub client — handles resume, progress, Python-compatible cache, auth; do not hand-roll URLSession HF calls
- **SwiftUI + iOS 17 @Observable:** Native declarative UI — @Observable is significantly cleaner than ObservableObject for streaming token output
- **SwiftData:** Lightweight model metadata persistence — Core Data is overkill for a flat model list
- **Swift Concurrency (actors + AsyncStream):** Inference loop and download management — actors prevent data races on llama.cpp context

### Expected Features

**Must have (table stakes):**
- HF Hub browse and search (GGUF/text-generation filter) — users assume this exists
- Background download with progress, ETA, cancel — 1-8GB files require this; foreground session is wrong
- Streaming chat UI with tokens/sec display — non-streaming feels broken vs. cloud apps
- Model library with delete and storage display — storage is scarce on iPhone
- Offline operation post-download — the core value proposition
- Storage-aware download warning before confirming — "Uses 4.2 GB, you have 6.1 GB free"
- Plain-language quantization labels ("balanced", "high quality", "fast/small") — Q4_K_M is opaque
- Basic inference parameters (temperature, system prompt)

**Should have (competitive differentiators — the moat):**
- Hard compatibility filtering — block downloads that cannot run on the device; no existing iOS app does this
- Three-tier soft compatibility ("Runs well / Runs slowly / Won't run") with token/sec estimates
- Device-aware model detail view with compatibility verdict pre-download
- Chat history persistence (v1.x, after validation)
- Inference parameter controls beyond defaults (v1.x)

**Defer (v2+):**
- RAG / document upload — massive scope expansion; own pipeline (chunking, embeddings, vector search)
- Multimodal / image model support — explicitly deferred per PROJECT.md
- LoRA adapter management — niche, low value for v1
- iPad layout — iPhone first per PROJECT.md

### Architecture Approach

A layered MVVM with feature modules (Browse, Library, Chat), a service layer instantiated once at app root and injected via SwiftUI environment, and two cross-cutting services (DeviceCapabilityService, CompatibilityEngine). CompatibilityEngine is a pure function — `(ModelMetadata, DeviceSpecs) → CompatibilityResult` — with no I/O, enabling exhaustive unit testing. InferenceService exposes inference as an `AsyncThrowingStream<String, Error>` bridged from llama.cpp callbacks; ChatViewModel iterates with `for await` on a detached Task, marshaling to MainActor only for UI updates.

**Major components:**
1. **DeviceCapabilityService** — detects RAM, chip family, free storage once at startup; injected everywhere; never queried ad hoc from views
2. **CompatibilityEngine** — pure function mapping (ModelMetadata, DeviceSpecs) to CompatibilityResult enum; annotates HF search results before display
3. **HFAPIService** — URLSession + Codable DTOs for HF Hub REST; debounced search, ETag caching, graceful 429 handling
4. **DownloadService** — background URLSession with stable per-model identifiers; reconstructed in AppDelegate on relaunch; files moved immediately in delegate callback
5. **InferenceService** — llama.cpp XCFramework wrapper; one context kept resident per loaded model; generation on detached Task
6. **ModelFileStore + SwiftData** — GGUF files in Documents directory (not Caches); SwiftData for metadata and download state

### Critical Pitfalls

1. **Total RAM vs. available RAM** — `physicalMemory` is not the app budget; jetsam gives ~40% of physical RAM. Use chip generation as primary compatibility proxy; use `os_proc_available_memory()` for runtime checks. Requires `com.apple.developer.kernel.increased-memory-limit` entitlement.
2. **Metal init from background thread = hard crash** — never auto-load a model when a download completes; always gate model load on `UIApplication.shared.applicationState == .active`.
3. **KV cache OOM mid-conversation** — context memory scales linearly with `n_ctx`. Cap per device tier (2048 max on Q4/A-series; 512-1024 safer on older devices). Never expose `n_ctx` as a free text field.
4. **Background URLSession lifecycle** — download temp file is deleted after `urlSession(_:downloadTask:didFinishDownloadingTo:)` returns; session must be reconstructed with same identifier on app relaunch; `invalidateAndCancel()` kills in-flight transfers.
5. **HF API rate limits unhandled** — debounce search input; cache metadata with ETag; surface 429s explicitly; support optional user HF token.
6. **GGUF metadata blindly trusted** — treat pre-download compatibility as estimated; parse GGUF header post-download for ground truth; always sum `siblings` file sizes, never use filename-derived estimates.

## Implications for Roadmap

### Phase 1: Device Foundation
**Rationale:** DeviceCapabilityService and CompatibilityEngine have no dependencies and must exist before any other component. The compatibility moat is worthless without correct device spec detection — getting RAM wrong means shipping a broken feature. Highest-risk correctness problem in the project.
**Delivers:** DeviceCapabilityService (chip, RAM, storage detection), CompatibilityEngine (hard/soft verdict), entitlement configuration, unit test suite for compatibility logic.
**Addresses:** Pre-download compatibility filtering (core differentiator), storage-aware warnings
**Avoids:** Total RAM vs. jetsam RAM pitfall (Pitfall 1), hardcoded device tables (never acceptable)

### Phase 2: HF Browse + Compatibility UI
**Rationale:** HFAPIService has no deps beyond networking; Browse feature depends on HFAPIService + CompatibilityEngine both being ready. This phase proves the core differentiator is visible and working before any download logic exists.
**Delivers:** HFAPIService (search, metadata, file listing), BrowseView + BrowseViewModel, compatibility badges on model rows, model detail view, quantization plain-language labels, rate limit handling.
**Addresses:** HF Hub browse/search (table stakes), hard filtering, soft compatibility tiers, plain-language quant labels
**Avoids:** HF API rate limit pitfall (Pitfall 5), GGUF metadata trust pitfall (Pitfall 6 — flag ambiguous metadata at browse time)

### Phase 3: Download + Model Library
**Rationale:** DownloadService depends on ModelFileStore; Library feature depends on both. Background URLSession is the highest-complexity infrastructure piece and must be correct before inference can be validated end-to-end.
**Delivers:** DownloadService (background URLSession, resume, progress), ModelFileStore (Documents directory, SwiftData schema), LibraryView + LibraryViewModel, storage display, model delete.
**Addresses:** Background download with progress (table stakes), model library management, storage-aware download warning
**Avoids:** Background URLSession teardown pitfall (Pitfall 4), Caches directory anti-pattern

### Phase 4: Inference + Chat
**Rationale:** InferenceService depends on ModelFileStore to resolve GGUF paths. Chat is the final validation of the full pipeline. n_ctx caps must be built in from the start, not retrofitted.
**Delivers:** InferenceService (llama.cpp wrapper, AsyncThrowingStream, context lifecycle), ChatView + ChatViewModel (streaming, tokens/sec, abort), thermal state monitoring, n_ctx caps per device tier.
**Addresses:** Streaming chat UI (table stakes), tokens/sec display, offline operation validation
**Avoids:** Background thread Metal crash (Pitfall 2), KV cache OOM (Pitfall 3), inference on MainActor anti-pattern, context-per-message anti-pattern

### Phase 5: Polish + V1.x Features
**Rationale:** Once the full pipeline is validated, add features users will immediately request without risking core stability.
**Delivers:** Chat history persistence (SwiftData), inference parameter controls (temperature, system prompt), model search filters, thermal throttling UI warnings, download pause/resume, load progress in chat UI.
**Addresses:** V1.x features from FEATURES.md, UX pitfalls (no abort, no pause/resume, chat blocked during load)
**Avoids:** Thermal throttling appearing as a bug (Pitfall 7)

### Phase Ordering Rationale

- **Infra before features:** The compatibility engine is worthless if device detection is wrong. Building it first with tests catches the jetsam RAM mistake before it ships.
- **Browse before download:** Proving the browse + compatibility UI works without download complexity makes it easier to validate the core differentiator in isolation.
- **Download before inference:** The background URLSession lifecycle is independent of llama.cpp; isolating it prevents conflating two hard problems.
- **n_ctx caps in Phase 4 not Phase 5:** This is a correctness requirement, not polish. Shipping inference without device-appropriate context caps will produce crash reports.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1 (Device Foundation):** Jetsam limit math per chip generation needs validation on physical devices; entitlement behavior under different memory limits needs testing before the compatibility ruleset is finalized.
- **Phase 3 (Download):** Background URLSession in iOS 17-18 has evolved; `handleEventsForBackgroundURLSession` lifecycle and concurrent task limits (≤4) should be verified against current Apple docs.
- **Phase 4 (Inference):** llama.cpp Swift XCFramework API surface changes with each release; the token callback bridging pattern to AsyncThrowingStream needs verification against b5046+ API before writing InferenceService.

Phases with standard patterns (skip research-phase):
- **Phase 2 (Browse UI):** HF Hub REST API is well-documented; swift-huggingface handles most of it; standard SwiftUI list + search patterns apply.
- **Phase 5 (Polish):** All features are additive; standard SwiftData persistence and SwiftUI form patterns apply.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Key choices verified via official HF blog, Swift Package Index, ggml-org releases. XCFramework vs. source SPM decision confirmed by GitHub issue #10371. |
| Features | HIGH | Cross-referenced against 4+ competitor apps (PocketPal, LLMFarm, LM Studio, Enclave AI). Competitor gap analysis is thorough. |
| Architecture | MEDIUM | MVVM + service injection patterns are established iOS practice. Specific llama.cpp Swift bridging patterns are MEDIUM — community sources, not official llama.cpp docs. |
| Pitfalls | MEDIUM-HIGH | RAM/jetsam and background URLSession pitfalls verified via Apple docs. Thermal throttling numbers from peer-reviewed study. Background Metal crash from community post-mortems. |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Jetsam limit table by chip:** Exact per-chip jetsam ceilings need validation on physical hardware during Phase 1. The compatibility ruleset cannot be finalized until this is measured.
- **Multi-shard GGUF detection:** The `siblings` parsing logic for detecting multi-part GGUF files needs a concrete test case; the exact HF API response shape for sharded models is unverified.
- **HF API rate limits in production:** Anonymous rate limits are undocumented by HF. Actual limits need to be measured or found in HF community forums before finalizing the debounce/cache strategy.
- **llama.cpp XCFramework Swift API surface:** Specific Swift entry points for token callbacks and context management in b5046+ should be confirmed from XCFramework headers before writing InferenceService.

## Sources

### Primary (HIGH confidence)
- https://huggingface.co/blog/swift-huggingface — swift-huggingface 0.8.0 features, installation, HubApi migration
- https://github.com/ggml-org/llama.cpp/releases — XCFramework binary artifacts and checksums
- https://swiftpackageindex.com/ggml-org/llama.cpp — SPM compatibility, iOS 14+ support
- https://developer.apple.com/documentation/os/3191911-os_proc_available_memory — available memory API
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.kernel.increased-memory-limit — memory limit entitlement
- https://developer.apple.com/documentation/Foundation/downloading-files-in-the-background — background URLSession lifecycle
- https://arxiv.org/html/2603.23640 — thermal throttling study (peer-reviewed)
- https://github.com/ggml-org/llama.cpp/issues/10371 — Objective-C++ SPM compilation failures

### Secondary (MEDIUM confidence)
- https://github.com/a-ghorbani/pocketpal-ai — PocketPal AI feature set and HF integration patterns
- https://github.com/guinmoon/LLMFarm — LLMFarm iOS feature set
- https://enclaveai.app/blog/ — quantization tiers for iPhone RAM, HF GGUF integration patterns
- https://www.callstack.com/blog/local-llms-on-mobile-are-a-gimmick — real-world pain points
- https://github.com/ggml-org/llama.cpp/discussions/4423 — llama.cpp iOS device discussion
- https://medium.com/@nnrajesh3006/the-tiered-inference-strategy-solving-the-ios-llm-background-crash — Metal background crash pattern
- https://www.avanderlee.com/swift/urlsession-common-pitfalls-with-background-download-upload-tasks/ — URLSession background pitfalls

### Tertiary (LOW confidence)
- https://elephas.app/blog/lm-studio-review — LM Studio desktop feature baseline (blog, review)
- https://dev.to/alichherawalla/how-to-run-llms-locally-on-your-iphone-in-2026-completely-offline-no-subscription-4b3a — iOS LLM landscape overview

---
*Research completed: 2026-04-08*
*Ready for roadmap: yes*
