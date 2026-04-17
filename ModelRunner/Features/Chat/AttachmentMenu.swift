import SwiftUI

/// Leading-side attachment menu for the chat input bar. Always rendered.
/// Vision-only options (Take photo / Attach photo) are disabled when the active
/// model can't process images. Files are always allowed — they'll be text-extracted
/// and prepended to the prompt in a later phase.
struct AttachmentMenu: View {
    var supportsVision: Bool = false
    var onAttachFile: () -> Void = {}
    var onTakePhoto: () -> Void = {}
    var onAttachPhoto: () -> Void = {}

    var body: some View {
        Menu {
            Button(action: onAttachFile) {
                Label("Attach file", systemImage: "folder")
            }
            Button(action: onTakePhoto) {
                Label("Take photo", systemImage: "camera")
            }
            .disabled(!supportsVision)
            Button(action: onAttachPhoto) {
                Label("Attach photo", systemImage: "photo")
            }
            .disabled(!supportsVision)
        } label: {
            Image(systemName: "plus")
                .font(.iconLG)
                .foregroundStyle(Color(hex: "#9896B0"))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(hex: "#1A1830").opacity(0.6))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                )
        }
        .accessibilityLabel("Attach")
    }
}

#Preview {
    ZStack {
        Color(hex: "#0D0C18").ignoresSafeArea()
        AttachmentMenu()
    }
}
