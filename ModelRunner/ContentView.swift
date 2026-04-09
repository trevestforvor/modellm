import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "cpu")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("ModelRunner")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
