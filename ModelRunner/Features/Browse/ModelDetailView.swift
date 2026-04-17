import SwiftUI

struct ModelDetailView: View {
    let model: AnnotatedModel

    @State private var detailedModel: AnnotatedModel?
    @State private var isLoading = false
    @State private var isDownloading = false
    @State private var downloadError: String?
    @State private var showCellularAlert = false
    @State private var cellularContinuation: CheckedContinuation<Bool, Never>?
    @State private var selectedVariant: AnnotatedVariant?
    @Environment(AppContainer.self) private var container

    private var displayModel: AnnotatedModel { detailedModel ?? model }

    private var activeVariant: AnnotatedVariant? {
        selectedVariant ?? bestDownloadVariant
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(Color.appTextTertiary)
                    Text(storageImpactText)
                        .font(.appSubheadline)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .listRowBackground(Color.appSurface)

            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(Color.appAccent)
                        Spacer()
                    }
                } else if displayModel.variants.isEmpty {
                    Text("No compatible variants for this device")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.appTextTertiary)
                } else {
                    ForEach(displayModel.variants) { variant in
                        let selectable = isSelectable(variant)
                        VariantRowView(variant: variant, isSelected: isSelected(variant))
                            .listRowBackground(Color.appSurface)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard selectable else { return }
                                selectedVariant = variant
                            }
                            .opacity(selectable ? 1 : 0.5)
                    }
                }
            } header: {
                Text("Variants")
                    .font(.appSubheadline)
                    .foregroundStyle(Color.appTextSecondary)
                    .textCase(nil)
            }
            .listRowBackground(Color.appSurface)

            Section {
                Button {
                    downloadSelectedVariant()
                } label: {
                    HStack {
                        Spacer()
                        if isDownloading {
                            ProgressView()
                                .tint(Color.appTextPrimary)
                                .padding(.trailing, 8)
                            Text("Downloading...")
                                .font(.appHeadline)
                                .foregroundStyle(Color.appTextPrimary)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(Color.appTextPrimary)
                            Text(downloadButtonLabel)
                                .font(.appHeadline)
                                .foregroundStyle(Color.appTextPrimary)
                        }
                        Spacer()
                    }
                }
                .disabled(activeVariant == nil || isDownloading)
                .buttonStyle(.borderedProminent)
                .tint(activeVariant != nil && !isDownloading ? Color.appAccent : Color.appAccent.opacity(0.4))
                .frame(maxWidth: .infinity)
                .accessibilityHint(activeVariant != nil ? "Download this model to your device" : "No compatible variant available")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(displayModel.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Link(destination: URL(string: "https://huggingface.co/\(displayModel.repoId)")!) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(Color.appAccent)
                }
                .accessibilityLabel("View on Hugging Face")
            }
        }
        .task {
            await loadDetail()
        }
        .onChange(of: displayModel.variants.map(\.filename)) { _, _ in
            reseedSelectionIfNeeded()
        }
        .alert("Cellular Download", isPresented: $showCellularAlert) {
            Button("Download", role: .destructive) {
                cellularContinuation?.resume(returning: true)
                cellularContinuation = nil
            }
            Button("Cancel", role: .cancel) {
                cellularContinuation?.resume(returning: false)
                cellularContinuation = nil
            }
        } message: {
            let size = activeVariant?.metadata.fileSizeBytes
                .map { UInt64($0).formattedFileSize } ?? "this model"
            Text("This will use ~\(size) of cellular data. Continue?")
        }
        .alert("Download Error", isPresented: .init(
            get: { downloadError != nil },
            set: { if !$0 { downloadError = nil } }
        )) {
            Button("OK") { downloadError = nil }
        } message: {
            Text(downloadError ?? "")
        }
    }

    // MARK: - Selection

    private func isSelectable(_ variant: AnnotatedVariant) -> Bool {
        variant.result.tier != .incompatible
    }

    private func isSelected(_ variant: AnnotatedVariant) -> Bool {
        activeVariant?.filename == variant.filename
    }

    private func reseedSelectionIfNeeded() {
        let filenames = Set(displayModel.variants.map(\.filename))
        if let current = selectedVariant, !filenames.contains(current.filename) {
            selectedVariant = nil
        }
        if selectedVariant == nil {
            selectedVariant = bestDownloadVariant
        }
    }

    private func loadDetail() async {
        guard let engine = container.compatibilityEngine else { return }
        isLoading = true
        defer {
            isLoading = false
            reseedSelectionIfNeeded()
        }

        let vm = HFBrowseViewModel(hfAPI: container.hfAPIService, compatibilityEngine: engine)
        if let detailed = try? await vm.fetchDetail(for: model) {
            detailedModel = detailed
        }
    }

    private var storageImpactText: String {
        let variantSize = activeVariant?.metadata.fileSizeBytes
            ?? displayModel.primaryResult?.metadata.fileSizeBytes

        let freeBytes = (try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage) ?? nil

        let sizeStr = variantSize.map { $0.formattedFileSize } ?? "Unknown size"

        if let free = freeBytes, free > 0 {
            let freeFormatted = UInt64(free).formattedFileSize
            return "Uses \(sizeStr) · You have \(freeFormatted) free"
        } else {
            return "Uses \(sizeStr)"
        }
    }

    // MARK: - Download

    private var bestDownloadVariant: AnnotatedVariant? {
        displayModel.bestVariant ?? displayModel.variants.first(where: { isSelectable($0) })
    }

    private var downloadButtonLabel: String {
        guard let variant = activeVariant else {
            return "No Compatible Variant"
        }
        let size = variant.metadata.fileSizeBytes.map { UInt64($0).formattedFileSize } ?? ""
        return "Download \(variant.quantType.rawValue) · \(size)"
    }

    private func downloadSelectedVariant() {
        guard let variant = activeVariant else { return }
        isDownloading = true
        downloadError = nil

        Task {
            do {
                try await container.downloadService.beginDownload(
                    repoId: displayModel.repoId,
                    filename: variant.filename,
                    fileSizeBytes: Int64(variant.metadata.fileSizeBytes ?? 0),
                    displayName: displayModel.displayName,
                    quantization: variant.quantType.rawValue,
                    authToken: nil,
                    deviceService: container.deviceService,
                    cellularConfirmation: { await requestCellularConfirmation() }
                )
            } catch {
                downloadError = error.localizedDescription
            }
            isDownloading = false
        }
    }

    private func requestCellularConfirmation() async -> Bool {
        await withCheckedContinuation { continuation in
            cellularContinuation = continuation
            showCellularAlert = true
        }
    }
}
