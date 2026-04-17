import SwiftUI

struct MyModelCard: View {
    let model: PickerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(sourceDotColor)
                    .frame(width: 8, height: 8)
                Text(sourceLabel)
                    .font(.appCaption)
                    .foregroundStyle(Color(hex: "#6B6980"))
                Spacer()
            }
            .padding(.bottom, 10)

            Text(model.displayName)
                .font(.appHeadline)
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let serverName = model.serverName {
                Text(serverName)
                    .font(.appCaption)
                    .foregroundStyle(Color(hex: "#6B6980"))
                    .padding(.top, 3)
            }

            Spacer(minLength: 10)

            HStack {
                if let tokPerSec = model.tokPerSec {
                    Text(String(format: "%.0f tok/s", tokPerSec))
                        .font(.appMonoSmall)
                        .foregroundStyle(Color(hex: "#4D6CF2"))
                } else {
                    Text("— tok/s")
                        .font(.appMonoSmall)
                        .foregroundStyle(Color(hex: "#6B6980"))
                }

                Spacer()

                capabilityBadge
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#1A1830"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color(hex: "#302E42"), lineWidth: 1)
                )
        )
        .opacity(model.isOnline ? 1.0 : 0.45)
    }

    private var sourceDotColor: Color {
        if !model.isOnline { return Color(hex: "#ef4444") }
        if case .local = model.source { return Color(hex: "#4D6CF2") }
        return Color(hex: "#22c55e")
    }

    private var sourceLabel: String {
        if case .local = model.source { return "On Device" }
        return model.serverName ?? "Remote"
    }

    @ViewBuilder
    private var capabilityBadge: some View {
        if !model.isOnline {
            Text("offline")
                .font(.appCaption)
                .foregroundStyle(Color(hex: "#ef4444"))
        } else if model.supportsThinking {
            badgePill(text: "🧠 think", color: Color(hex: "#4D6CF2"))
        } else if case .local = model.source {
            badgePill(text: "Runs Well", color: Color(hex: "#22c55e"))
        }
    }

    private func badgePill(text: String, color: Color) -> some View {
        Text(text)
            .font(.appCaption)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.15))
            )
    }
}
