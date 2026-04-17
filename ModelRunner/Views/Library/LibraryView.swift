import SwiftUI
import SwiftData

/// Library tab — shows all downloaded models, sorted by last-used date (D-08).
/// DLST-03: View all downloaded models with size and last-used date.
/// DLST-04: Delete models to free storage (swipe-to-delete + bulk edit).
/// DLST-05: Tap to set active model.
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppContainer.self) private var container

    /// @Query provides automatic SwiftData-backed list with live updates.
    /// Sort by lastUsedDate descending — most recently used at top (D-08, RESEARCH Pattern 10).
    @Query(sort: \DownloadedModel.lastUsedDate, order: .reverse)
    private var models: [DownloadedModel]

    @State private var libraryService = LibraryService()
    @State private var modelToDelete: DownloadedModel?
    @State private var showDeleteConfirmation = false
    @State private var freeStorageBytes: Int64 = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                Group {
                    if models.isEmpty {
                        emptyState
                    } else {
                        modelList
                    }
                }
            }
            .navigationTitle("Library")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if !models.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
        }
        .task {
            freeStorageBytes = Int64((try? await container.deviceService.availableStorage) ?? 0)
        }
        .confirmationDialog(deleteConfirmationTitle, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    performDelete(model)
                }
            }
            Button("Cancel", role: .cancel) {
                modelToDelete = nil
            }
        } message: {
            if let model = modelToDelete {
                Text("This will free \(model.formattedSize) of storage.")
            }
        }
    }

    // MARK: - Subviews

    private var modelList: some View {
        List {
            // D-13: Storage summary header
            Section {
                storageHeader
            }

            // Model list
            Section {
                ForEach(models) { model in
                    LibraryModelCard(model: model)
                        .onTapGesture {
                            activateModel(model)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                modelToDelete = model
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .onDelete { indexSet in
                    // Bulk delete from Edit mode
                    for index in indexSet {
                        let model = models[index]
                        modelToDelete = model
                        showDeleteConfirmation = true
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var storageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Models: \(models.count)")
                    .font(.figtree(.subheadline, weight: .medium))
                Text("\(libraryService.formattedTotalStorage(models: models)) used · \(libraryService.formattedFreeStorage(freeBytes: freeStorageBytes)) free")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "internaldrive")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)

            Text("No Models Downloaded")
                .font(.outfit(.title3, weight: .semibold))

            Text("Browse Hugging Face models and download one that's compatible with your device.")
                .font(.figtree(.subheadline))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func activateModel(_ model: DownloadedModel) {
        do {
            try libraryService.toggleActive(model, in: models, context: modelContext)
        } catch {
            // Non-fatal — state will sync on next @Query refresh
            print("[LibraryView] setActiveModel failed: \(error)")
        }
    }

    private func performDelete(_ model: DownloadedModel) {
        do {
            try libraryService.deleteModel(model, context: modelContext)
            modelToDelete = nil
            // Refresh free storage after deletion
            Task {
                freeStorageBytes = Int64((try? await container.deviceService.availableStorage) ?? 0)
            }
        } catch {
            print("[LibraryView] deleteModel failed: \(error)")
        }
    }

    private var deleteConfirmationTitle: String {
        guard let model = modelToDelete else { return "Delete Model?" }
        return "Delete \(model.displayName)?"
    }
}

#Preview {
    LibraryView()
        .environment(AppContainer.shared)
}
