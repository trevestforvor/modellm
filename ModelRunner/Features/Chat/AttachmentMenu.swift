import SwiftUI

/// Leading-side attachment menu for the chat input bar.
/// Only rendered when the active model declares `supportsVision == true`. Real picker
/// integration (PhotosPicker, UIImagePickerController, fileImporter) lands in a later phase —
/// for now each option fires its closure and the parent logs.
struct AttachmentMenu: View {
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
            Button(action: onAttachPhoto) {
                Label("Attach photo", systemImage: "photo")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color(hex: "#9896B0"))
                .frame(width: 36, height: 36)
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "#0D0C18").ignoresSafeArea()
        AttachmentMenu()
    }
}
