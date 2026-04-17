import SwiftUI
import SwiftData

struct ServerListView: View {
    @Query(sort: \ServerConnection.addedAt) private var servers: [ServerConnection]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddServer = false

    private let background    = Color(hex: "#0D0C18")
    private let surface       = Color(hex: "#1A1830")
    private let accent        = Color(hex: "#4D6CF2")
    private let secondaryText = Color(hex: "#9896B0")
    private let muted         = Color(hex: "#6B6980")

    var body: some View {
        Group {
            if servers.isEmpty {
                emptyState
            } else {
                serverList
            }
        }
        .navigationTitle("Servers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddServer = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(accent)
                }
                .accessibilityLabel("Add server")
            }
        }
        .sheet(isPresented: $showingAddServer) {
            NavigationStack {
                AddServerView()
            }
        }
    }

    private var emptyState: some View {
        ZStack {
            background.ignoresSafeArea()
            ContentUnavailableView(
                "No Servers",
                systemImage: "server.rack",
                description: Text("Add a remote inference server to run models off-device.")
            )
        }
    }

    private var serverList: some View {
        List {
            ForEach(servers) { server in
                NavigationLink(destination: ServerDetailView(server: server)) {
                    ServerRowView(server: server)
                }
                .listRowBackground(surface)
            }
            .onDelete(perform: deleteServers)
        }
        .scrollContentBackground(.hidden)
        .background(background)
    }

    private func deleteServers(at offsets: IndexSet) {
        for index in offsets {
            let server = servers[index]
            if let keyRef = server.apiKeyRef {
                KeychainService.delete(account: keyRef)
            }
            modelContext.delete(server)
        }
    }
}

// MARK: - Server Row

private struct ServerRowView: View {
    let server: ServerConnection

    private let secondaryText = Color(hex: "#9896B0")
    private let muted         = Color(hex: "#6B6980")

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(server.isActive ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.appBody)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(server.baseURL)
                    .font(.appCaption)
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(server.activeFormat.displayName)
                    .font(.appCaption)
                    .foregroundStyle(muted)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
