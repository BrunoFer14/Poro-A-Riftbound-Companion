import SwiftUI
import FirebaseAuth

// MARK: - Messages List

struct MessagesListView: View {
    let viewModel: MarketplaceViewModel
    let authService: AuthService

    var body: some View {
        Group {
            if viewModel.isLoadingConversations {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.conversations.isEmpty {
                ContentUnavailableView(
                    "Sem mensagens",
                    systemImage: "message",
                    description: Text("As tuas conversas com compradores e vendedores aparecem aqui.")
                )
            } else {
                List(viewModel.conversations) { conv in
                    NavigationLink(value: conv) {
                        ConversationRowView(
                            conversation: conv,
                            currentUserId: authService.currentUser?.uid ?? ""
                        )
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.hideConversation(conv.id)
                        } label: {
                            Label("Remover", systemImage: "trash")
                        }
                    }
                }
                .listStyle(.plain)
                .navigationDestination(for: Conversation.self) { conv in
                    ConversationView(
                        conversation: conv,
                        authService: authService,
                        onConversationUpdated: {}
                    )
                }
            }
        }
    }
}

// MARK: - Conversation Row

private struct ConversationRowView: View {
    let conversation: Conversation
    let currentUserId: String

    private var unread: Int { conversation.unread(for: currentUserId) }

    var body: some View {
        HStack(spacing: 12) {
            CardImageView(url: conversation.listingCardImageUrl, width: 44, height: 61)
                .clipShape(.rect(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.listingCardName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(conversation.lastMessageAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(conversation.otherUserName(currentUserId: currentUserId))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.2f €", conversation.listingPrice))
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                }

                if !conversation.lastMessage.isEmpty {
                    Text(conversation.lastMessage)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            if unread > 0 {
                Text("\(unread)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.accentColor, in: .capsule)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Conversation (Chat) View

struct ConversationView: View {
    let conversation: Conversation
    let authService: AuthService
    let onConversationUpdated: () -> Void

    @State private var convViewModel = ConversationViewModel()
    @FocusState private var inputFocused: Bool

    private var currentUserId: String { authService.currentUser?.uid ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            // Listing info banner
            listingBanner

            Divider()

            // Messages
            if convViewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(convViewModel.messages) { message in
                                MessageBubble(
                                    message: message,
                                    isFromMe: message.senderId == currentUserId
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: convViewModel.messages.count) {
                        if let last = convViewModel.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }

            Divider()

            // Input bar
            inputBar
        }
        .navigationTitle(conversation.otherUserName(currentUserId: currentUserId))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            convViewModel.listenToMessages(
                conversationId: conversation.id,
                currentUserId: currentUserId
            )
        }
        .onDisappear {
            convViewModel.stopListening()
        }
    }

    private var listingBanner: some View {
        HStack(spacing: 10) {
            CardImageView(url: conversation.listingCardImageUrl, width: 36, height: 50)
                .clipShape(.rect(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.listingCardName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(String(format: "%.2f €", conversation.listingPrice))
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Mensagem...", text: $convViewModel.newMessageText, axis: .vertical)
                .lineLimit(1...4)
                .padding(10)
                .background(.quaternary, in: .rect(cornerRadius: 20))
                .focused($inputFocused)

            Button {
                Task {
                    guard let uid = authService.currentUser?.uid,
                          let name = authService.displayName ?? authService.email
                    else { return }
                    try? await convViewModel.sendMessage(
                        conversation: conversation,
                        senderId: uid,
                        senderName: name
                    )
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(convViewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.secondary : Color.accentColor)
            }
            .disabled(convViewModel.newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: Message
    let isFromMe: Bool

    var body: some View {
        HStack {
            if isFromMe { Spacer(minLength: 60) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 2) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(isFromMe ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isFromMe ? Color.accentColor : Color.secondary.opacity(0.2),
                        in: .rect(
                            cornerRadii: RectangleCornerRadii(
                                topLeading: 18,
                                bottomLeading: isFromMe ? 18 : 4,
                                bottomTrailing: isFromMe ? 4 : 18,
                                topTrailing: 18
                            )
                        )
                    )

                Text(message.sentAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if !isFromMe { Spacer(minLength: 60) }
        }
    }
}
