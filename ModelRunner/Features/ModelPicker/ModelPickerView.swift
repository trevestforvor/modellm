import SwiftUI
import SwiftData

struct ModelPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var pickerVM = ModelPickerViewModel()

    let onSelect: (PickerModel) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0C18").ignoresSafeArea()

                if pickerVM.isLoading {
                    ProgressView("Loading models...")
                        .foregroundStyle(Color(hex: "#9896B0"))
                        .tint(Color(hex: "#8B7CF0"))
                } else if pickerVM.sections.isEmpty {
                    ContentUnavailableView(
                        "No Models Available",
                        systemImage: "cpu",
                        description: Text("Download a model or add a remote server in Settings.")
                    )
                } else {
                    modelList
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(hex: "#9896B0"))
                }
            }
            .task {
                await pickerVM.load(modelContext: modelContext)
            }
        }
    }

    private var modelList: some View {
        List {
            ForEach(pickerVM.sections) { section in
                Section(section.title) {
                    ForEach(section.models) { model in
                        Button {
                            onSelect(model)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.displayName)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(model.isOnline ? .white : Color(hex: "#6B6980"))

                                    if !model.isOnline {
                                        Text("offline")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.red.opacity(0.7))
                                    }
                                }

                                Spacer()

                                if model.supportsThinking {
                                    Image(systemName: "brain")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(hex: "#8B7CF0").opacity(0.7))
                                }

                                if let tokPerSec = model.tokPerSec {
                                    Text(String(format: "%.1f tok/s", tokPerSec))
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(Color(hex: "#9896B0"))
                                } else {
                                    Text("— tok/s")
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(Color(hex: "#6B6980"))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(!model.isOnline)
                        .listRowBackground(Color(hex: "#1A1830"))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}
