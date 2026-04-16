import SwiftUI

struct EngineResultRow: View {
    let result: EngineTranscriptionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(String(format: "%.1fs", result.wallClockSeconds))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: "#9896B0"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(Color(hex: "#302E42"))
                    )
            }

            if let err = result.error {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.45))
                    .textSelection(.enabled)
            } else if result.text.isEmpty {
                Text("(no transcript)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#6B6980"))
            } else {
                Text(result.text)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#1A1830"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(hex: "#302E42"), lineWidth: 0.5)
                )
        )
    }

    private var displayName: String {
        // Engine displayName lives on the backend; we don't have it here.
        // We surface a derived label from the engine ID.
        switch result.engineID {
        case "whisperkit-distil-small-en": return "WhisperKit · distil-small.en"
        case "whisperkit-base-en": return "WhisperKit · base.en"
        case "apple-on-device": return "Apple SFSpeechRecognizer"
        default: return result.engineID
        }
    }
}
