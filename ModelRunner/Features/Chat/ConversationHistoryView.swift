import SwiftUI
import SwiftData

struct ConversationHistoryView: View {
    @Query(sort: \Conversation.updatedAt, order: .reverse)
    private var allConversations: [Conversation]

    /// Current model identity — only show conversations for this model
    var currentModelIdentity: String?

    let onSelect: (Conversation) -> Void
    let onDismiss: () -> Void
    let onDelete: (Conversation) -> Void

    @State private var conversationToDelete: Conversation?
    @State private var showDeleteAlert = false

    /// Filter to current model, then group by model for section headers
    private var conversations: [Conversation] {
        guard let identity = currentModelIdentity, !identity.isEmpty else {
            return allConversations
        }
        return allConversations.filter { $0.modelIdentity == identity }
    }

    private var grouped: [(modelId: String, displayName: String, convs: [Conversation])] {
        let dict = Dictionary(grouping: conversations, by: \.modelIdentity)
        return dict.map { (modelId: $0.key, displayName: $0.value.first?.modelDisplayName ?? $0.key, convs: $0.value) }
            .sorted { lhs, rhs in
                let lDate = lhs.convs.first?.updatedAt ?? .distantPast
                let rDate = rhs.convs.first?.updatedAt ?? .distantPast
                return lDate > rDate
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar with dismiss X button
            historyHeader

            if conversations.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                        ForEach(grouped, id: \.modelId) { group in
                            // Section header
                            Text(group.displayName)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color(hex: "#9896B0"))
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .padding(.bottom, 4)

                            // Conversation rows
                            ForEach(group.convs) { conv in
                                conversationRow(conv)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            conversationToDelete = conv
                                            showDeleteAlert = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .defaultScrollAnchor(.bottom)
            }
        }
        .alert("Delete Conversation?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let conv = conversationToDelete {
                    onDelete(conv)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This conversation will be permanently deleted.")
        }
    }

    private var historyHeader: some View {
        HStack {
            Text("Conversations")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "#9896B0"))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color(hex: "#1A1830").opacity(0.6))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                    )
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func conversationRow(_ conv: Conversation) -> some View {
        Button {
            onSelect(conv)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(conv.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer()
                Text(relativeDate(conv.updatedAt))
                    .font(.caption.monospaced())
                    .foregroundStyle(Color(hex: "#6B6980"))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "#6B6980"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#1A1830").opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32))
                .foregroundStyle(Color(hex: "#6B6980"))
            Text("No conversations yet")
                .font(.body)
                .foregroundStyle(Color(hex: "#9896B0"))
            Text("Start typing to begin")
                .font(.footnote)
                .foregroundStyle(Color(hex: "#6B6980"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private func relativeDate(_ date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}
