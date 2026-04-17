import SwiftUI

struct ModelDetailView: View {
    let model: AnnotatedModel

    @State private var detailedModel: AnnotatedModel?
    @State private var isLoading = false
    @State private var isDownloading = false
    @State private var downloadError: String?
    @State private var showCellularAlert = false
    @State private var cellularContinuation: CheckedContinuation<Bool, Never>?
    @Environment(AppContainer.self) private var container

    private let cardSurface   = Color(hex: "#0D0C18")
    private let primaryText   = Color(hex: "#EDEDF4")
    private let secondaryText = Color(hex: "#9896B0")
    private let tertiaryText  = Color(hex: "#6B6980")
    private let border        = Color(hex: "#302E42")
    private let accent        = Color(hex: "#4D6CF2")

    private var displayModel: AnnotatedModel { detailedModel ?? model }

    var body: some View {
        List {
            // MARK: Storage Impact
            Section {
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(tertiaryText)
                    Text(storageImpactText)
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
            }
            .listRowBackground(cardSurface)

            // MARK: Variants
            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(accent)
                        Spacer()
                    }
                } else if displayModel.variants.isEmpty {
                    Text("No compatible variants for this device")
                        .font(.subheadline)
                        .foregroundStyle(tertiaryText)
                } else {
                    ForEach(displayModel.variants) { variant in
                        VariantRowView(variant: variant)
                            .listRowBackground(cardSurface)
                    }
                }
            } header: {
                Text("Variants")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(secondaryText)
                    .textCase(nil)
            }
            .listRowBackground(cardSurface)

            // MARK: Download Button
            Section {
                Button {
                    downloadBestVariant()
                } label: {
                    HStack {
                        Spacer()
                        if isDownloading {
                            ProgressView()
                                .tint(primaryText)
                                .padding(.trailing, 8)
                            Text("Downloading...")
                                .font(.headline)
                                .foregroundStyle(primaryText)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(primaryText)
                            Text(downloadButtonLabel)
                                .font(.headline)
                                .foregroundStyle(primaryText)
                        }
                        Spacer()
                    }
                }
                .disabled(bestDownloadVariant == nil || isDownloading)
                .buttonStyle(.borderedProminent)
                .tint(bestDownloadVariant != nil && !isDownloading ? accent : accent.opacity(0.4))
                .frame(maxWidth: .infinity)
                .accessibilityHint(bestDownloadVariant != nil ? "Download this model to your device" : "No compatible variant available")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(displayModel.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Link(destination: URL(string: "https://huggingface.co/\(displayModel.repoId)")!) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(accent)
                }
                .accessibilityLabel("View on Hugging Face")
            }
        }
        .task {
            await loadDetail()
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
            let size = bestDownloadVariant?.metadata.fileSizeBytes
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

    private func loadDetail() async {
        guard let engine = container.compatibilityEngine else { return }
        isLoading = true
        defer { isLoading = false }

        // Create a temporary view model just for detail fetching
        let vm = HFBrowseViewModel(hfAPI: container.hfAPIService, compatibilityEngine: engine)
        if let detailed = try? await vm.fetchDetail(for: model) {
            detailedModel = detailed
        }
    }

    private var storageImpactText: String {
        let variantSize = displayModel.bestVariant?.metadata.fileSizeBytes
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
        displayModel.bestVariant ?? displayModel.variants.first
    }

    private var downloadButtonLabel: String {
        guard let variant = bestDownloadVariant else {
            return "No Compatible Variant"
        }
        let size = variant.metadata.fileSizeBytes.map { UInt64($0).formattedFileSize } ?? ""
        return "Download \(variant.quantType.rawValue) · \(size)"
    }

    private func downloadBestVariant() {
        guard let variant = bestDownloadVariant else { return }
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
