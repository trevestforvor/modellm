import SwiftUI
import SwiftData

/// Library tab — shows all downloaded models.
/// Full implementation in Plan 04.
struct LibraryView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0F0E1A").ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "tray.full")
                        .font(.largeTitle)
                        .foregroundStyle(Color(hex: "#6B6980"))
                    Text("Library")
                        .font(.headline)
                        .foregroundStyle(Color(hex: "#9896B0"))
                    Text("Download models to see them here")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#6B6980"))
                }
            }
            .navigationTitle("Library")
        }
    }
}

#Preview {
    LibraryView()
}
