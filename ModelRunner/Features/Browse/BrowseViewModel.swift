import Foundation
import Observation

// MARK: - Browse Error

enum HFBrowseError: Error, LocalizedError {
    case apiError(HFAPIError)
    case unknown(Error)

    init(from error: Error) {
        if let apiError = error as? HFAPIError {
            self = .apiError(apiError)
        } else {
            self = .unknown(error)
        }
    }

    var errorDescription: String? {
        switch self {
        case .apiError(let e): return e.errorDescription
        case .unknown(let e): return e.localizedDescription
        }
    }
}

// MARK: - View Model

@Observable
@MainActor
final class HFBrowseViewModel {

    // MARK: Search State

    var searchQuery: String = "" {
        didSet { onSearchQueryChanged(searchQuery) }
    }
    var isSearching: Bool = false
    var isLoadingNextPage: Bool = false
    var searchError: HFBrowseError?

    // MARK: Recommendations State

    var recommendations: [AnnotatedModel] = []
    var recommendationsError: HFBrowseError?
    var isLoadingRecommendations: Bool = false

    // MARK: Search Results

    var searchResults: [AnnotatedModel] = []
    var hasMoreResults: Bool = false

    // MARK: Private

    private var nextPageOffset: Int = 0
    private var currentSearchQuery: String = ""
    private var searchTask: Task<Void, Never>?
    private let debounceMilliseconds: UInt64 = 350

    private let hfAPI: HFAPIService
    private let compatibilityEngine: CompatibilityEngine

    // MARK: Init

    init(hfAPI: HFAPIService, compatibilityEngine: CompatibilityEngine) {
        self.hfAPI = hfAPI
        self.compatibilityEngine = compatibilityEngine
    }

    // MARK: - Load Initial Data

    /// Call once when BrowseView appears. Loads recommendations then awaits user search.
    func loadInitialData() async {
        await loadRecommendations()
    }

    // MARK: - Recommendations (HFIN-04)

    func loadRecommendations() async {
        guard recommendations.isEmpty else { return }  // idempotent
        isLoadingRecommendations = true
        defer { isLoadingRecommendations = false }

        do {
            // D-14: fetch top downloads, filter to runsWell, take 5
            let raw = try await hfAPI.searchGGUFModels(query: "", offset: 0)
            let annotated = raw
                .compactMap { annotate(hfModel: $0) }
                .filter { $0.bestVariant != nil }            // D-14: only truly runsWell
                .sorted { $0.downloadCount > $1.downloadCount }
            recommendations = Array(annotated.prefix(5))
            recommendationsError = nil
        } catch {
            // D-13: hide recommendations section on error — don't surface in landing UX
            recommendationsError = HFBrowseError(from: error)
            recommendations = []
        }
    }

    // MARK: - Search (HFIN-01, HFIN-02)

    private func onSearchQueryChanged(_ query: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: debounceMilliseconds * 1_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(query: query, reset: true)
        }
    }

    private func performSearch(query: String, reset: Bool) async {
        if reset {
            nextPageOffset = 0
            searchResults = []
            currentSearchQuery = query
        }
        guard !isSearching else { return }
        isSearching = true
        defer { isSearching = false }

        do {
            let raw = try await hfAPI.searchGGUFModels(query: query, offset: nextPageOffset)
            let annotated = raw
                .compactMap { annotate(hfModel: $0) }
                .filter { $0.primaryResult != nil }        // D-05: hide incompatible
                .sorted { sortKey($0) > sortKey($1) }     // D-03: runsWell first
            searchResults.append(contentsOf: annotated)
            hasMoreResults = raw.count == hfAPI.pageSize
            nextPageOffset += raw.count
            searchError = nil
        } catch {
            searchError = HFBrowseError(from: error)
            // Preserve existing results on error
        }
    }

    func loadNextPage() async {
        guard hasMoreResults && !isLoadingNextPage && !isSearching else { return }
        isLoadingNextPage = true
        defer { isLoadingNextPage = false }
        await performSearch(query: currentSearchQuery, reset: false)
    }

    // MARK: - Detail (HFIN-03)

    /// Fetches fresh model detail with all variants annotated.
    func fetchDetail(for model: AnnotatedModel) async throws -> AnnotatedModel {
        let detail = try await hfAPI.fetchModelDetail(repoId: model.repoId)
        return annotate(hfModel: detail) ?? model  // fall back to cached if annotation fails
    }

    // MARK: - Annotation

    /// Converts an HF API response to an AnnotatedModel.
    /// Returns nil if the model produces zero compatible variants (D-05).
    private func annotate(hfModel: HFModelListResponse) -> AnnotatedModel? {
        let paramCount = hfModel.estimatedParameterCount
        let variants: [AnnotatedVariant] = (hfModel.siblings ?? [])
            .filter { $0.isGGUF }
            .compactMap { sibling -> AnnotatedVariant? in
                guard let metadata = sibling.toModelMetadata(
                    repoId: hfModel.id,
                    paramCount: paramCount
                ) else { return nil }
                let result = compatibilityEngine.evaluate(metadata)
                // D-05: exclude incompatible variants entirely
                guard result.tier != .incompatible else { return nil }
                return AnnotatedVariant(
                    id: sibling.rfilename,
                    metadata: metadata,
                    result: result
                )
            }

        // D-05: if all variants are incompatible, hide the model
        guard !variants.isEmpty else { return nil }

        return AnnotatedModel(
            id: hfModel.id,
            repoId: hfModel.id,
            displayName: hfModel.displayName,
            downloadCount: hfModel.downloads,
            variants: variants
        )
    }

    // MARK: - Sort

    /// Higher return value = appears first. runsWell (2) before runsSlow (1).
    private func sortKey(_ model: AnnotatedModel) -> Int {
        switch model.primaryResult?.result.tier {
        case .runsWell:  return 2
        case .runsSlow:  return 1
        default:         return 0
        }
    }
}
