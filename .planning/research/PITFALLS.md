# Pitfalls Research

**Domain:** On-device iOS LLM runner (Hugging Face + llama.cpp)
**Researched:** 2026-04-08
**Confidence:** MEDIUM-HIGH (verified via GitHub issues, Apple docs, community post-mortems)

---

## Critical Pitfalls

### Pitfall 1: Treating Total RAM as Available RAM

**What goes wrong:**
`sysctlbyname("hw.memsize")` returns physical RAM (e.g., 8GB), but iOS restricts app memory via jetsam limits. On a 6GB iPhone, the app budget is typically 2.5–3GB, not 6GB. Compatibility checks based on total RAM will greenlight models that immediately crash on load.

**Why it happens:**
Total RAM feels like the right signal. Available memory is dynamic and harder to reason about at browse-time.

**How to avoid:**
Use `os_proc_available_memory()` for runtime checks. For pre-download compatibility, use chip generation as the primary proxy (A15+ for 7B Q4, A17 Pro / A18 for 7B Q5+). Cross-reference the `com.apple.developer.kernel.increased-memory-limit` entitlement — without it, memory ceilings are lower than the hardware suggests. Test limits on actual devices with `maxRecommendedWorkingSet` from llama.cpp's iOS example code.

**Warning signs:**
- App passes compatibility check but crashes on model load
- Models load fine in Simulator but crash on physical device
- Compatibility checks pass on reviewer's newer device but fail in user reports on older ones

**Phase to address:** Device compatibility / model filtering phase (before download is enabled)

---

### Pitfall 2: Running Inference from a Background Thread Triggers Hard Crash

**What goes wrong:**
iOS prohibits initializing a Metal compute context from a background thread. If inference is started (or the model is loaded) while the app is backgrounded, iOS terminates the process. This is particularly dangerous when a download completes in the background and triggers automatic model loading.

**Why it happens:**
Developers chain download → load → ready notification without guarding for app state. Looks fine in testing (Xcode keeps app foregrounded).

**How to avoid:**
Always check `UIApplication.shared.applicationState == .active` before loading or running inference. Use a deferred loading pattern: download completes → mark as "ready to load" → load when app returns to foreground via `sceneDidBecomeActive`. Never auto-load on download completion.

**Warning signs:**
- Works perfectly in development (Xcode attached prevents suspension)
- Users report crashes after leaving the app during long downloads
- Crash logs show `EXC_CRASH` from Metal thread violations

**Phase to address:** Download + inference pipeline integration phase

---

### Pitfall 3: Context Window Size Causes Silent OOM

**What goes wrong:**
KV cache memory scales linearly with context length. A 7B model at Q4_K_M may fit in RAM, but setting `n_ctx=4096` doubles or triples memory use, pushing the app over jetsam limits. The crash happens at inference time, not load time, so compatibility checks pass.

**Why it happens:**
Developers test with default or small context windows. Context is treated as a user preference, not a memory budget line item. llama.cpp's default `n_ctx` is 512 but many tutorials demonstrate with 2048+.

**How to avoid:**
Calculate context memory as part of the compatibility model: `KV cache ≈ 2 * n_layers * n_ctx * n_embd * bytes_per_element`. Cap `n_ctx` per quantization tier. For Q4 on A-series, 2048 is the safe ceiling on most devices; 512–1024 is safer for older phones. Expose context length as an advanced setting with device-appropriate defaults, not a free text field.

**Warning signs:**
- App crashes only during long conversations, not at start
- Higher-end test devices work fine, mid-range devices crash after N messages
- Memory profiler shows gradual growth per-token until jetsam kill

**Phase to address:** Inference configuration / chat UI phase

---

### Pitfall 4: Background URLSession Teardown Loses Download State

**What goes wrong:**
Using a foreground `URLSession` for multi-gigabyte downloads means the transfer dies when the user leaves the app. If using a background `URLSessionConfiguration`, the session identity must survive app restart — failing to reconstruct the session with the same identifier in `application(_:handleEventsForBackgroundURLSession:)` means completion events are dropped and the downloaded file is lost by the system daemon.

**Why it happens:**
Background sessions have a non-obvious lifecycle: `nsurlsessiond` holds the file, not your app. If you don't reclaim it within the delegate callback window, the temp file is deleted. Using non-unique session identifiers across multiple simultaneous downloads causes sessions to collide.

**How to avoid:**
- Use `URLSessionConfiguration.background(withIdentifier:)` with a stable per-download identifier (e.g., `"com.app.download.\(modelId)"`)
- Implement `application(_:handleEventsForBackgroundURLSession:)` in `AppDelegate` and reconstruct the session there
- Store the downloaded file immediately in `urlSession(_:downloadTask:didFinishDownloadingTo:)` — the temp URL is deleted after this delegate returns
- Keep concurrent background download tasks to ≤ 4

**Warning signs:**
- Downloads silently vanish when app is backgrounded for more than a few minutes
- Works with small files, breaks on 3GB+ files
- Users report having to restart downloads repeatedly

**Phase to address:** Model download / storage management phase

---

### Pitfall 5: Hugging Face API Rate Limits Unhandled in Browse/Search

**What goes wrong:**
The Hugging Face Hub API has rate limits on unauthenticated requests. Heavy search or metadata fetching (e.g., paginating model lists, fetching file trees for many models) hits 429s. This surfaces as empty search results or broken compatibility data with no user-facing explanation.

**Why it happens:**
Development uses a personal token and never hits limits. Production with many anonymous users does.

**How to avoid:**
- Cache model metadata aggressively (ETag-based invalidation, not time-based)
- Gate API calls: debounce search input, don't fetch per-keystroke
- Surface rate limit errors explicitly ("Unable to load models — try again in a moment")
- Support optional HF token entry for users who want unlimited API access
- Use the `X-RateLimit-*` response headers to implement backoff

**Warning signs:**
- Search works in development but fails intermittently in TestFlight
- 429 responses appearing in logs with no retry logic
- Metadata fetch succeeds for first N models then silently returns empty

**Phase to address:** Hugging Face API integration / browse phase

---

### Pitfall 6: GGUF Metadata Trusted Blindly for Compatibility

**What goes wrong:**
GGUF file headers contain model metadata (parameter count, quantization type, architecture), but this data is user-supplied by the model uploader and can be wrong, incomplete, or use non-standard naming conventions. A model tagged as `Q4_K_M` in the filename may have different actual quantization; a file listed as 7B may be a different size variant. Compatibility checks built on filename parsing or API metadata fail silently.

**Why it happens:**
Hugging Face model cards and filenames are free-form. The ecosystem has strong conventions but no enforcement. Developers assume the metadata is authoritative.

**How to avoid:**
- Parse the GGUF header directly for the actual `general.quantization_version` and `llama.context_length` fields after download (not before)
- Pre-download compatibility should be treated as "estimated" — flag models with ambiguous metadata
- Show a post-load verification step that confirms actual memory footprint matches expectations
- For the HF API, use `siblings` array file sizes as ground truth for storage estimation; ignore filename-derived estimates

**Warning signs:**
- A "compatible" model fails to load after downloading
- Memory usage at inference doesn't match pre-download estimates
- Models with non-standard naming (e.g., community fine-tunes) break the compatibility logic

**Phase to address:** Compatibility engine + model metadata phase

---

### Pitfall 7: Thermal Throttling Degrades Inference Mid-Session

**What goes wrong:**
iPhone 16 Pro loses ~44% inference throughput within 2 inference iterations under sustained load once the device enters the "Hot" thermal state. Users experience fast first responses followed by progressively slower tokens — appearing as a bug, not a hardware constraint.

**Why it happens:**
Testing uses short prompts and brief sessions. Sustained load triggers Apple's thermal management, which throttles CPU/GPU/ANE frequency.

**How to avoid:**
- Surface thermal state to the user: `ProcessInfo.processInfo.thermalState` — show a warning when `.serious` or `.critical`
- Pause inference (don't cancel) when thermal state reaches `.critical`; resume on cooldown
- Set user expectations in the UI: "Performance may decrease during extended sessions"
- Recommend short context windows on older devices to reduce per-token compute

**Warning signs:**
- Token generation rate drops significantly after 5+ minutes of continuous use
- Device gets warm and speed halves
- TestFlight feedback mentions "it gets slow"

**Phase to address:** Inference pipeline / chat UI phase

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcode device compatibility table | Ships fast, no RAM API complexity | Breaks on new device releases, requires app updates | Never — use chip + RAM tiers dynamically |
| Foreground-only URLSession for downloads | Much simpler code | Downloads fail when user leaves app, 0/10 UX | Never for > 500MB files |
| Trust HF API file size for storage check | Simple | Wrong for split GGUF shards; total must be summed across siblings | Never — always sum `siblings` |
| Max context window by default | Simple UX | OOM crashes on mid-range devices | Never — default to conservative value |
| No thermal state handling | Ships faster | App appears buggy when device heats up | MVP only with prominent "experimental" label |
| Download to temp dir without immediate move | Simple | Background session temp file deleted after delegate returns | Never |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| llama.cpp Swift bindings | Using `unsafeFlags(_:)` in SPM to build | Use precompiled XCFramework as `binaryTarget` — enables semantic versioning |
| llama.cpp model load | Calling `llama_load_model_from_file` on main thread | Always dispatch to a background serial queue; use async Task with actor isolation |
| Hugging Face API — model list | Fetching all models then filtering client-side | Use `search`, `filter=gguf`, and `tags` query params server-side to reduce payload |
| Hugging Face API — file tree | Fetching `/api/models/{id}` siblings for every model in list | Batch: only fetch siblings when user taps a model detail |
| URLSession background | Calling `session.invalidateAndCancel()` on app relaunch | Reconstruct same-identifier session instead; `invalidateAndCancel` kills in-flight transfers |
| GGUF shard detection | Treating each shard as a standalone model | Check `siblings` for `*.gguf` pattern — multi-shard files must all be downloaded together |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Unbounded KV cache | OOM crash mid-conversation | Cap `n_ctx` by device tier in compatibility engine | After ~10 conversation turns on mid-range devices |
| Metal context on background thread | Hard crash / EXC_CRASH | Guard all Metal init behind foreground check | First time user leaves app during or after download |
| Polling HF API for search suggestions | 429 rate limit errors | Debounce 400ms + cache last results | Under moderate usage (>20 requests/min) |
| Loading model synchronously on main thread | UI freeze for 10-30 seconds | Background queue + progress callback | Every model load |
| Keeping model loaded when app backgrounds | Jetsam kill under memory pressure | Free model context on `sceneWillResignActive` for large models on low-RAM devices | Under OS memory pressure |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Showing total device RAM in compatibility UI | Users think 8GB phone can run any model | Show "usable app memory" (~40% of total), not physical RAM |
| No download pause/resume | Users must restart multi-GB downloads on interruption | Use resumable `URLSessionDownloadTask` with `resumeData` persistence |
| Compatibility shown as binary (yes/no) | Users download "compatible" models that run at 1 token/sec | Three-tier: "Runs well / Runs slowly / Won't run" with token/sec estimates |
| No storage pre-check before download | Download fails at 80% due to insufficient space | Check `URL.volumeAvailableCapacityForImportantUsageKey` before starting download |
| Chat blocked during model load | App appears frozen for 20-30 seconds at startup | Show load progress in chat UI — skeleton state with spinner and ETA |
| No way to abort inference | User sends wrong prompt, can't stop it | Implement `llama_set_abort_callback` to cancel generation mid-stream |

---

## "Looks Done But Isn't" Checklist

- [ ] **Compatibility engine:** Tested on actual mid-range iPhone (A15, 4GB accessible) — not just latest Pro
- [ ] **Download manager:** Verify file is accessible after app kill + relaunch mid-download
- [ ] **Model loading:** Verify no main thread stall via `dispatchPrecondition(condition: .notOnQueue(.main))`
- [ ] **Storage check:** Test on device with < 500MB free — graceful error, not crash
- [ ] **Chat UI:** Send 20+ messages in a row — verify no OOM and thermal warning appears if needed
- [ ] **Shard detection:** Test with a 2-shard GGUF — verify both parts are required and downloaded
- [ ] **HF API auth:** Test with no token — verify graceful rate limit handling, not silent empty results
- [ ] **Background download:** Lock phone mid-download — verify it completes and file is present on unlock
- [ ] **Memory entitlement:** Verify `com.apple.developer.kernel.increased-memory-limit` is in `.entitlements` file

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Wrong RAM-based compatibility (shipped) | HIGH | Add chip-tier lookup table, deprecate RAM-only check, push update |
| Foreground-only downloads shipped | MEDIUM | Swap `URLSession` configuration to background; requires session lifecycle refactor |
| Context window OOM crashes | LOW | Add `n_ctx` cap per-model in inference config; no architecture change needed |
| HF API rate limiting unhandled | LOW | Add retry-with-backoff + caching layer; purely additive |
| No thermal state handling | LOW | Additive `ProcessInfo` observer + UI warning; no core changes |
| Shard download incomplete | MEDIUM | Audit `siblings` parsing logic; may require re-download UX for affected users |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Total vs. available RAM | Device detection + compatibility engine | Load 4GB model on A15 4GB device — no crash |
| Background thread Metal crash | Download + inference integration | Kill app mid-download, relaunch, tap "Load" — no crash |
| Context window OOM | Inference configuration | Send 30 messages on 4GB device — no crash |
| Background URLSession teardown | Download manager | Background app for 10 min mid-download — transfer survives |
| HF API rate limits | Browse + search phase | Simulate 429 response — UI shows graceful error |
| GGUF metadata blindly trusted | Compatibility engine | Load model with mismatched filename — no silent failure |
| Thermal throttling | Chat UI polish phase | Run inference 15 min straight — thermal warning appears |

---

## Sources

- [URLSession: Common pitfalls with background download & upload tasks](https://www.avanderlee.com/swift/urlsession-common-pitfalls-with-background-download-upload-tasks/) — MEDIUM confidence
- [llama.cpp Discussion: Running on iOS devices](https://github.com/ggml-org/llama.cpp/discussions/4423) — HIGH confidence
- [Apple Developer Docs: os_proc_available_memory](https://developer.apple.com/documentation/os/3191911-os_proc_available_memory) — HIGH confidence
- [Apple Developer Docs: increased-memory-limit entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.kernel.increased-memory-limit) — HIGH confidence
- [Apple Developer Docs: Downloading files in the background](https://developer.apple.com/documentation/Foundation/downloading-files-in-the-background) — HIGH confidence
- [LLM Inference at the Edge — thermal throttling study](https://arxiv.org/html/2603.23640) — HIGH confidence (peer-reviewed)
- [The Tiered Inference Strategy: Solving the iOS LLM Background Crash](https://medium.com/@nnrajesh3006/the-tiered-inference-strategy-solving-the-ios-llm-background-crash-7e1195453188) — MEDIUM confidence
- [Practical GGUF Quantization Guide for iPhone](https://enclaveai.app/blog/2025/11/12/practical-quantization-guide-iphone-mac-gguf/) — MEDIUM confidence
- [Are Local LLMs on Mobile a Gimmick? The Reality in 2025](https://www.callstack.com/blog/local-llms-on-mobile-are-a-gimmick) — MEDIUM confidence
- [Local LLMs in GGUF format on iOS](https://medium.com/@nicolas2064/local-llms-in-gguf-format-on-ios-0acd0f95c250) — MEDIUM confidence
- [Scientific Witchery: LLaMA on iOS](https://www.jackyoustra.com/blog/llama-ios) — MEDIUM confidence

---
*Pitfalls research for: on-device iOS LLM runner (ModelRunner)*
*Researched: 2026-04-08*
