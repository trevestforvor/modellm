import SwiftUI

struct ModelDetailView: View {
    let model: AnnotatedModel

    @State private var detailedModel: AnnotatedModel?
    @State private var isLoading = false
    @Environment(AppContainer.self) private var container

    private let cardSurface   = Color(hex: "#0D0C18")
    private let primaryText   = Color(hex: "#EDEDF4")
    private let secondaryText = Color(hex: "#9896B0")
    private let tertiaryText  = Color(hex: "#6B6980")
    private let border        = Color(hex: "#302E42")
    private let accent        = Color(hex: "#8B7CF0")

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
                    // Phase 3: download action
                } label: {
                    HStack {
                        Spacer()
                        Text("Download · Coming Soon")
                            .font(.headline)
                            .foregroundStyle(primaryText)
                        Spacer()
                    }
                }
                .disabled(true)
                .buttonStyle(.borderedProminent)
                .tint(accent.opacity(0.4))
                .frame(maxWidth: .infinity)
                .accessibilityHint("Download available in a future update")
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
            }
        }
        .task {
            await loadDetail()
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
}
