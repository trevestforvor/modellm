# Phase 2 Research: HF Browse + Compatibility UI

**Phase:** 02 — HF Browse + Compatibility UI
**Date:** 2026-04-09
**Requirements:** HFIN-01, HFIN-02, HFIN-03, HFIN-04

---

## Summary

Phase 2 builds the browsable model catalog: users see GGUF models from Hugging Face, instantly filtered to what their device can actually run, with tok/s speed badges on every card. The compatibility engine (Phase 1) is already done. This phase is entirely about fetching model metadata from HF and rendering it with the right UX.

The core technical challenge is bridging HF Hub API responses to `ModelMetadata` — the type the compatibility engine already consumes. Once that mapping exists, the browse UI is a straightforward composition of existing Phase 1 primitives with new networking and views.

---

## 1. swift-huggingface API

### Installation

Already captured in STACK.md. Package.swift dependency:

```swift
.package(url: "https://github.com/huggingface/swift-huggingface.git", from: "0.8.0")
```

### Searching Models (HFIN-01, HFIN-02)

The swift-huggingface 0.8.0 `Hub` type is the primary entry point. The HF Hub REST API endpoint for model search is:

```
GET https://huggingface.co/api/models
    ?search=<query>
    &library=gguf
    &sort=downloads
    &direction=-1
    &limit=20
    &full=true
```

Key parameters:
- `library=gguf` — server-side GGUF filter (D-07). This is the correct parameter; `library_name` is an alias in some older docs but `library` works in the v1 API.
- `sort=downloads&direction=-1` — sorts by download count descending (aligns with D-14: recommendations sorted by download count)
- `full=true` — includes sibling files list in response. Required to get per-variant GGUF file metadata.
- `limit=20` — page size. HF API supports `offset` for pagination.

**Direct URLSession approach (recommended over swift-huggingface search wrapper):** swift-huggingface 0.8.0 focuses on file download and authentication; its search surface is limited. The browse feature should use `URLSession` with `Codable` DTOs directly against the HF API, with `Hub.TokenProvider` from swift-huggingface for auth token injection. This avoids depending on API-surface parts of swift-huggingface that may change.

```swift
// Endpoint: https://huggingface.co/api/models?search=llama&library=gguf&full=true&limit=20
struct HFModelListResponse: Decodable {
    let id: String              // "username/model-name"
    let modelId: String?        // same as id
    let downloads: Int
    let likes: Int
    let lastModified: String?
    let siblings: [HFSibling]?  // GGUF file variants — only present with full=true

    enum CodingKeys: String, CodingKey {
        case id, downloads, likes, lastModified = "lastModified", siblings
        case modelId = "modelId"
    }
}

struct HFSibling: Decodable {
    let rfilename: String  // e.g. "model-Q4_K_M.gguf", "tokenizer.json"
    let size: Int64?       // bytes — present in full response
    let blobId: String?
    let lfs: HFLFSMeta?

    struct HFLFSMeta: Decodable {
        let size: Int64      // actual file size in bytes (more reliable than siblings.size)
        let sha256: String?
    }
}
```

**File size priority:** `sibling.lfs.size` > `sibling.size` > nil. LFS size is always the actual file size; `siblings.size` may be the pointer file size (136 bytes) for large files stored in LFS.

### Fetching Model Detail (HFIN-03)

For the detail view, fetch the individual model card:

```
GET https://huggingface.co/api/models/<modelId>
```

Returns the full `HFModelListResponse` for one model plus `cardData` (YAML front matter from README.md, includes license, language, base model). No `full=true` needed — it's always full for single-model requests.

The siblings list in this response contains ALL files in the repo, including non-GGUF files (tokenizer.json, config.json, etc.). Filter to `.gguf` extension client-side.

### Authentication

swift-huggingface's `Hub.TokenProvider` handles HF token injection. For Phase 2, anonymous access suffices — the HF API allows unauthenticated reads with a 1000 req/day rate limit per IP. Token support should be scaffolded but not required.

```swift
// Inject token if available in keychain/UserDefaults
var request = URLRequest(url: url)
if let token = HFTokenStore.shared.token {
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
}
```

---

## 2. Mapping HF Response to ModelMetadata

`ModelMetadata` (from Phase 1 `CompatibilityModels.swift`) requires:
- `name: String`
- `fileSizeBytes: UInt64?`
- `parameterCount: Int?`
- `quantizationType: QuantizationType`
- `layerCount: Int?`
- `embeddingDim: Int?`

### Parsing Quantization Type from Filename

The filename encodes quantization type: `model-name-Q4_K_M.gguf`. Parse with a regex or string matching:

```swift
extension QuantizationType {
    /// Parses quantization type from a GGUF filename.
    /// e.g. "llama-3-8b-instruct.Q4_K_M.gguf" → .q4KM
    /// e.g. "gemma-2b-it-Q2_K.gguf" → .q2K
    static func fromFilename(_ filename: String) -> QuantizationType {
        let upper = filename.uppercased()
        // Check in specificity order — K_M before K to avoid partial match
        for quant in QuantizationType.allCases {
            if upper.contains(quant.rawValue) {
                return quant
            }
        }
        return .unknown
    }
}
```

`QuantizationType.allCases` is already implemented in `CompatibilityModels.swift` as a CaseIterable enum. Iteration order matters: check `Q4_K_M` before `Q4_K` and `Q4_0`. The enum case ordering in `allCases` should put more specific variants first. Verify this in the implementation.

### Parameter Count Extraction

HF API does not reliably return parameter count in the search response. Best-effort sources in priority order:

1. **Model name parsing** — "llama-3-8b" → 8B, "gemma-2b" → 2B. Pattern: look for `(\d+(\.\d+)?)b` (case-insensitive) in the model name or repo id.
2. **`safetensors_parameters` field** — some HF models include this in the search response when `full=true`. Sum all values for total param count.
3. **GGUF filename** — rare, but some repos encode it: "8b-instruct-q4_k_m.gguf".
4. **Nil** — CompatibilityEngine handles nil gracefully via D-10 (estimates from file size + quant type).

```swift
extension HFModelListResponse {
    /// Best-effort parameter count extraction from model id or name.
    var estimatedParameterCount: Int? {
        let text = id.lowercased()
        // Match patterns like "8b", "7b", "70b", "1.5b", "0.5b"
        let pattern = #"(\d+(?:\.\d+)?)b"#
        guard let match = text.range(of: pattern, options: .regularExpression) else { return nil }
        let numStr = text[match].dropLast() // remove trailing 'b'
        guard let billions = Double(numStr) else { return nil }
        return Int(billions * 1_000_000_000)
    }
}
```

### Full Mapping Function

```swift
extension HFSibling {
    /// Maps a single GGUF sibling file to ModelMetadata.
    func toModelMetadata(repoId: String) -> ModelMetadata? {
        guard rfilename.hasSuffix(".gguf") else { return nil }
        let bytes = (lfs?.size ?? size).map { UInt64($0) }
        return ModelMetadata(
            name: "\(repoId)/\(rfilename)",
            fileSizeBytes: bytes,
            parameterCount: nil,          // populated by caller with repo-level estimate
            quantizationType: QuantizationType.fromFilename(rfilename)
        )
    }
}
```

---

## 3. HFBrowseViewModel Architecture

### State

```swift
@Observable
final class HFBrowseViewModel {
    // Search
    var searchQuery: String = ""
    var isSearching: Bool = false

    // Data
    var recommendations: [AnnotatedModel] = []      // HFIN-04: chip-appropriate top picks
    var searchResults: [AnnotatedModel] = []         // HFIN-01, HFIN-02
    var hasMoreResults: Bool = false
    private var nextPageOffset: Int = 0

    // States
    var searchError: HFBrowseError? = nil
    var recommendationsError: HFBrowseError? = nil

    // Dependencies (injected)
    private let hfAPI: HFAPIService
    private let compatibilityEngine: CompatibilityEngine

    // Debounce
    private var searchTask: Task<Void, Never>? = nil
    private let debounceMilliseconds: Int = 350
}
```

`AnnotatedModel` is a new type for Phase 2: an HF model result with its compatibility result attached:

```swift
struct AnnotatedModel: Identifiable {
    let id: String                         // HF repo id
    let repoId: String                     // "username/model-name"
    let displayName: String                // extracted from repo id
    let downloadCount: Int
    let variants: [AnnotatedVariant]       // per-GGUF-file compatibility

    /// Best variant for this device — highest compatible quant by file size
    var bestVariant: AnnotatedVariant? {
        variants.filter { $0.result.tier == .runsWell }
                .max(by: { ($0.metadata.fileSizeBytes ?? 0) < ($1.metadata.fileSizeBytes ?? 0) })
    }

    /// Primary badge: best variant's tok/s range, or slowest compatible
    var primaryResult: AnnotatedVariant? {
        bestVariant ?? variants.filter { $0.result.tier == .runsSlow }.first
    }
}

struct AnnotatedVariant: Identifiable {
    let id: String                // rfilename
    let metadata: ModelMetadata
    let result: CompatibilityResult
    var filename: String { metadata.name.components(separatedBy: "/").last ?? metadata.name }
    var quantType: QuantizationType { metadata.quantizationType }
}
```

### Debounced Search

```swift
func onSearchQueryChanged(_ query: String) {
    searchTask?.cancel()
    searchTask = Task {
        // Debounce
        try? await Task.sleep(nanoseconds: UInt64(debounceMilliseconds) * 1_000_000)
        guard !Task.isCancelled else { return }
        await performSearch(query: query, reset: true)
    }
}

@MainActor
private func performSearch(query: String, reset: Bool) async {
    if reset { nextPageOffset = 0; searchResults = [] }
    isSearching = true
    defer { isSearching = false }
    do {
        let raw = try await hfAPI.searchGGUFModels(query: query, offset: nextPageOffset)
        let annotated = raw.compactMap { annotate(hfModel: $0) }
                          .filter { $0.primaryResult != nil }  // D-05: hide incompatible
                          .sorted { sortKey($0) > sortKey($1) } // D-03: runsWell first
        searchResults.append(contentsOf: annotated)
        hasMoreResults = raw.count == hfAPI.pageSize
        nextPageOffset += raw.count
        searchError = nil
    } catch {
        searchError = HFBrowseError(from: error)
    }
}
```

### Recommendations Algorithm (HFIN-04)

```swift
func loadRecommendations() async {
    // D-14: filter to runsWell, sort by downloads, take top 5
    let raw = try? await hfAPI.searchGGUFModels(query: "", offset: 0)
    let annotated = (raw ?? [])
        .compactMap { annotate(hfModel: $0) }
        .filter { $0.bestVariant != nil }          // only truly "Runs Well" models
        .sorted { $0.downloadCount > $1.downloadCount }
        .prefix(5)
    recommendations = Array(annotated)
}
```

### Sort Key

```swift
private func sortKey(_ model: AnnotatedModel) -> Int {
    switch model.primaryResult?.result.tier {
    case .runsWell:   return 2
    case .runsSlow:   return 1
    default:          return 0
    }
}
```

---

## 4. HFAPIService Implementation

```swift
actor HFAPIService {
    let pageSize = 20
    private let session: URLSession
    private var baseURL = URL(string: "https://huggingface.co/api")!
    private var token: String? // optional HF token

    func searchGGUFModels(query: String, offset: Int) async throws -> [HFModelListResponse] {
        var components = URLComponents(url: baseURL.appendingPathComponent("models"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = [
            .init(name: "library", value: "gguf"),
            .init(name: "sort", value: "downloads"),
            .init(name: "direction", value: "-1"),
            .init(name: "limit", value: "\(pageSize)"),
            .init(name: "full", value: "true"),
            .init(name: "offset", value: "\(offset)"),
        ]
        if !query.isEmpty { queryItems.append(.init(name: "search", value: query)) }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw HFAPIError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode([HFModelListResponse].self, from: data)
    }

    func fetchModelDetail(repoId: String) async throws -> HFModelListResponse {
        let url = baseURL.appendingPathComponent("models/\(repoId)")
        var request = URLRequest(url: url)
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(HFModelListResponse.self, from: data)
    }
}
```

**Caching:** Simple in-memory cache keyed by `(query, offset)` using a dictionary in the actor. TTL of 5 minutes prevents redundant API calls when navigating back to browse. No disk cache in Phase 2.

**Rate limiting:** HF API returns `X-RateLimit-Remaining` header. On 429, surface a user-facing error: "Too many requests — try again in a moment."

---

## 5. Pagination / Infinite Scroll

The UI-SPEC specifies infinite scroll. Pattern:

```swift
// In BrowseView, at end of LazyVStack:
if hasMoreResults {
    ProgressView()
        .onAppear { Task { await viewModel.loadNextPage() } }
}
```

`loadNextPage()` calls `performSearch(query: currentQuery, reset: false)` with the current offset. The `nextPageOffset` accumulates correctly because `performSearch` appends rather than replaces.

**Guard against duplicate loads:** wrap in a `isLoadingNextPage: Bool` flag, set before the async call, cleared in defer.

---

## 6. Navigation Architecture

**Decision (Claude's discretion per D-09):** NavigationStack push for detail view. Reasons:
- Detail view is content-dense (variant list can be long). Sheet feels cramped.
- NavigationStack push gives standard iOS back-button behavior, no accidental dismissal.
- Consistent with what users expect from catalog apps (App Store, etc.).

```swift
NavigationStack {
    BrowseView()
        .navigationDestination(for: AnnotatedModel.self) { model in
            ModelDetailView(model: model)
        }
}
```

`AnnotatedModel` conforms to `Hashable` for NavigationStack destinations.

---

## 7. Empty, Loading, and Error States

Per D-08 and UI-SPEC:

**Loading state:** `ProgressView()` centered in the list area while first fetch is in flight. Not a shimmer/skeleton — keep it simple for Phase 2.

**Empty state (no results):** When `searchResults.isEmpty && !isSearching && searchError == nil`:
```
[magnifyingglass icon, 40pt]
"No GGUF models found"
"Try a different search term"
```

**Error state:** When `searchError != nil`:
```
[exclamationmark.triangle icon, 40pt]
"Couldn't load models"
"Check your connection and try again"  [Retry button]
```

**Recommendations error:** If recommendations fail, hide the section entirely (don't show an error in the landing experience — just fall through to the search interface).

---

## 8. Quantization Type Display

The UI-SPEC metadata row shows quantization type as a string. Use `QuantizationType.rawValue` directly:
- `.q4KM` → "Q4_K_M"
- `.q2K` → "Q2_K"
- `.unknown` → omit from display (show "—" in detail view)

For the metadata row on cards (D-04), format as: `"7B · Q4_K_M · 4.1 GB · 12.4K downloads"`.

File size formatting:
```swift
extension UInt64 {
    var formattedFileSize: String {
        let gb = Double(self) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(self) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}

extension Int {
    var formattedDownloadCount: String {
        if self >= 1_000_000 { return String(format: "%.1fM", Double(self) / 1_000_000) }
        if self >= 1_000 { return String(format: "%.1fK", Double(self) / 1_000) }
        return "\(self)"
    }
}
```

---

## 9. AppContainer Integration

Phase 1's `AppContainer` already holds `compatibilityEngine`. Phase 2 adds `HFAPIService`:

```swift
@Observable
final class AppContainer {
    let deviceService = DeviceCapabilityService()
    let hfAPIService = HFAPIService()
    private(set) var compatibilityEngine: CompatibilityEngine?

    init() {
        Task {
            await deviceService.initialize()
            if let specs = await deviceService.specs {
                self.compatibilityEngine = CompatibilityEngine(device: specs)
            }
        }
    }
}
```

`HFBrowseViewModel` is created in `BrowseView` as a `@State` property and receives services via initializer injection (not `@Environment` directly — the VM is the @Observable, not the services):

```swift
struct BrowseView: View {
    @Environment(AppContainer.self) var container
    @State private var viewModel: HFBrowseViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                BrowseContentView(viewModel: vm)
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            guard let engine = container.compatibilityEngine else { return }
            viewModel = HFBrowseViewModel(hfAPI: container.hfAPIService, compatibilityEngine: engine)
            Task { await viewModel?.loadInitialData() }
        }
    }
}
```

This handles the async initialization of `compatibilityEngine` — it may be nil for a few milliseconds at launch.

---

## 10. File Structure for Phase 2

Following ARCHITECTURE.md's recommended structure:

```
ModelRunner/
  Features/
    Browse/
      BrowseView.swift               # Root view: recommendations + search
      BrowseViewModel.swift          # @Observable view model
      ModelCardView.swift            # Individual model card
      ModelDetailView.swift          # Detail push view
      VariantRowView.swift           # Per-file variant row in detail
      ToksBadgeView.swift            # Reusable tok/s pill badge component
  Services/
    HF/
      HFAPIService.swift             # actor: networking + pagination
      HFModels.swift                 # HFModelListResponse, HFSibling Codable DTOs
      HFAPIError.swift               # Error enum
      AnnotatedModel.swift           # AnnotatedModel, AnnotatedVariant value types
      QuantizationParser.swift       # QuantizationType.fromFilename(_:)
```

---

## 11. Known Pitfalls

1. **LFS size vs sibling size:** `sibling.size` for LFS-tracked files is the pointer file size (136 bytes), not the actual model size. Always use `sibling.lfs.size` when available. Log a warning when LFS metadata is absent.

2. **Non-GGUF files in siblings list:** Filter strictly to `.gguf` extension. Some repos include `.safetensors`, `.bin`, `.json`, etc. in the siblings array.

3. **Empty sibling list with `full=false`:** The `siblings` array is only populated when the request includes `full=true`. Forgetting this parameter produces models with no variants.

4. **Rate limit on launch:** Loading recommendations at launch + initial search simultaneously could hit rate limits. Serialize: load recommendations first, then wait for user to type before search.

5. **`compatibilityEngine` nil at launch:** AppContainer initializes asynchronously. BrowseView must handle `compatibilityEngine == nil` gracefully — show a loading state rather than crashing on force-unwrap.

6. **Parameter count parsing false positives:** Model ids like "phi-3-mini-128k-instruct" contain "3" and "128" — the parser must match `\d+b` specifically, not bare numbers.

7. **`QuantizationType.allCases` ordering:** Ensure `Q4_K_M` appears before `Q4_K` and `Q4_0` in the enum definition so `fromFilename` matches correctly. The current `CompatibilityModels.swift` should be verified.

8. **HF API field naming inconsistency:** The API uses both camelCase (`modelId`, `lastModified`) and snake_case (`model_id`) in different endpoints/versions. Use explicit `CodingKeys` on all DTOs.

---

## Validation Architecture

This section defines how Phase 2 code is tested without live network calls.

### Unit: HFAPIService (mock URLSession)

Create `MockURLSession` conforming to a `URLSessionProtocol`:

```swift
protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// HFAPIService takes URLSessionProtocol — defaults to URLSession.shared in prod
actor HFAPIService {
    private let session: any URLSessionProtocol
    init(session: any URLSessionProtocol = URLSession.shared, token: String? = nil) { ... }
}
```

Test fixtures: JSON files in `ModelRunnerTests/Fixtures/` — `hf_search_gguf.json`, `hf_model_detail.json`, `hf_search_empty.json`, `hf_search_rate_limit.json`.

Each fixture mirrors the actual HF API response structure. Tests verify:
- `searchGGUFModels` returns correct `HFModelListResponse` array
- LFS size is preferred over sibling size
- HTTP 429 throws `HFAPIError.rateLimited`
- Empty results array decodes correctly (not nil)

### Unit: QuantizationType.fromFilename

Pure function — test directly with a table of filenames:

```swift
XCTAssertEqual(QuantizationType.fromFilename("llama-3-8b.Q4_K_M.gguf"), .q4KM)
XCTAssertEqual(QuantizationType.fromFilename("gemma-2b-Q2_K.gguf"), .q2K)
XCTAssertEqual(QuantizationType.fromFilename("model.Q4_K_S.gguf"), .q4KS)
XCTAssertEqual(QuantizationType.fromFilename("model.gguf"), .unknown)
XCTAssertEqual(QuantizationType.fromFilename("MODEL.Q8_0.GGUF"), .q8_0) // uppercase
```

### Unit: HFBrowseViewModel

Inject mock `HFAPIService` and a real `CompatibilityEngine` built from a test `DeviceSpecs`:

```swift
let testSpecs = DeviceSpecs(
    chipIdentifier: "iPhone15,2",
    chipProfile: ChipProfile(generation: .a17Pro, ...),
    physicalRAM: 8 * 1024 * 1024 * 1024,
    jetsamBudget: 5 * 1024 * 1024 * 1024,
    osVersion: .init(majorVersion: 17, minorVersion: 0, patchVersion: 0)
)
let engine = CompatibilityEngine(device: testSpecs)
let mockAPI = MockHFAPIService(fixture: .searchResults)
let vm = HFBrowseViewModel(hfAPI: mockAPI, compatibilityEngine: engine)
```

Test scenarios:
- `loadInitialData()` populates `recommendations` with `runsWell`-only models
- `onSearchQueryChanged("llama")` triggers debounced search after 350ms
- Search error sets `searchError`, leaves existing results intact
- Incompatible models are filtered out of `searchResults`
- `loadNextPage()` appends to existing results, increments offset

### Unit: Compatibility Badge Rendering

`ToksBadgeView` receives a `CompatibilityResult` and renders the correct color. Test via ViewInspector (if available) or snapshot test:
- `.runsWell(estimatedTokensPerSec: 20...30)` → green background, "~25 tok/s" text
- `.runsSlowly(estimatedTokensPerSec: 5...10, warning: "...")` → orange background, "~7 tok/s" text
- `.incompatible(...)` → view is not rendered (caller filters before passing to card)

### Integration: Search Debounce

Use `Task` with `XCTestExpectation` to verify debounce fires after 350ms and cancels on rapid input:

```swift
func testDebounceFiresOnce() async {
    let exp = XCTestExpectation(description: "search called once")
    let mockAPI = MockHFAPIService { exp.fulfill() }
    let vm = HFBrowseViewModel(hfAPI: mockAPI, compatibilityEngine: engine)
    vm.onSearchQueryChanged("a")
    vm.onSearchQueryChanged("ab")
    vm.onSearchQueryChanged("abc")
    await fulfillment(of: [exp], timeout: 1.0)
    XCTAssertEqual(mockAPI.searchCallCount, 1)
}
```

### Integration: End-to-End (Xcode Simulator)

Manual verification checklist (run on device or simulator with real HF API access):
- [ ] Browse screen loads with recommendations on first launch
- [ ] Search for "llama" shows GGUF models with tok/s badges
- [ ] "Won't Run" models are not visible in results
- [ ] Tapping a model card pushes detail view
- [ ] Detail view shows all GGUF variants with individual tok/s badges
- [ ] Scrolling to bottom of results loads next page
- [ ] No-results state appears for a nonsense search term
- [ ] Error state appears when device is offline

---

## Sources

- swift-huggingface 0.8.0 announcement: https://huggingface.co/blog/swift-huggingface
- HF Hub REST API reference: https://huggingface.co/docs/hub/api
- Existing project research: `.planning/research/STACK.md`, `.planning/research/ARCHITECTURE.md`
- Phase 1 type contracts: `ModelRunner/Services/Device/CompatibilityModels.swift`
- Phase 1 engine: `ModelRunner/Services/Device/CompatibilityEngine.swift`
