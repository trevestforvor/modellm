import SwiftUI

struct MyModelsSection: View {
    let models: [PickerModel]
    let onSelectModel: (PickerModel) -> Void
    let onAddServer: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MY MODELS")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#9896B0"))
                    .tracking(0.5)

                Spacer()

                Button(action: onAddServer) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text("Add Server")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color(hex: "#5E6AD2"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#1A1830"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color(hex: "#302E42"), style: StrokeStyle(lineWidth: 1, dash: [4]))
                            )
                    )
                }
            }

            if models.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cpu")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(hex: "#302E42"))
                    Text("No models yet")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color(hex: "#9896B0"))
                    Text("Add a remote server or download a model to get started")
                        .font(.footnote)
                        .foregroundStyle(Color(hex: "#6B6980"))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(models) { model in
                        Button {
                            if model.isOnline {
                                Haptics.soft()
                                onSelectModel(model)
                            }
                        } label: {
                            MyModelCard(model: model)
                        }
                        .buttonStyle(.pressScale)
                    }
                }
            }
        }
    }
}
