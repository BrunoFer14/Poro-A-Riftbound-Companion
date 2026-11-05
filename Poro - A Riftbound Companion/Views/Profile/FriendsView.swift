import SwiftUI

struct FriendsView: View {
    let friendsService: FriendsService
    let cardCache: CardCache
    let authService: AuthService

    @State private var showSearch = false
    @State private var errorMessage: String?

    private var accepted: [Friend] {
        friendsService.friends.filter { $0.status == .accepted }
    }

    private var pendingIncoming: [Friend] {
        friendsService.friends.filter { $0.status == .pending && !$0.initiator }
    }

    private var pendingOutgoing: [Friend] {
        friendsService.friends.filter { $0.status == .pending && $0.initiator }
    }

    var body: some View {
        List {
            if !pendingIncoming.isEmpty {
                Section("Pedidos recebidos") {
                    ForEach(pendingIncoming) { friend in
                        PendingRequestRow(friend: friend) {
                            await accept(friend)
                        } onDecline: {
                            await remove(friend)
                        }
                    }
                }
            }

            if !pendingOutgoing.isEmpty {
                Section("Pedidos enviados") {
                    ForEach(pendingOutgoing) { friend in
                        HStack {
                            AvatarView(name: friend.displayName)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.displayName).font(.subheadline.weight(.medium))
                                Text(friend.email).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Pendente")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await remove(friend) }
                            } label: {
                                Label("Cancelar", systemImage: "xmark")
                            }
                        }
                    }
                }
            }

            Section("Amigos (\(accepted.count))") {
                if accepted.isEmpty {
                    Text("Ainda não tens amigos. Adiciona alguém pelo email.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(accepted) { friend in
                        NavigationLink(value: friend) {
                            HStack {
                                AvatarView(name: friend.displayName)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName).font(.subheadline.weight(.medium))
                                    Text(friend.email).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await remove(friend) }
                            } label: {
                                Label("Remover", systemImage: "person.badge.minus")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Amigos")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Friend.self) { friend in
            FriendCollectionView(friend: friend, cardCache: cardCache)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSearch = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showSearch) {
            AddFriendSheet(friendsService: friendsService)
        }
        .alert("Erro", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func accept(_ friend: Friend) async {
        do { try await friendsService.acceptRequest(from: friend.uid) }
        catch { errorMessage = error.localizedDescription }
    }

    private func remove(_ friend: Friend) async {
        do { try await friendsService.removeFriend(friend.uid) }
        catch { errorMessage = error.localizedDescription }
    }
}

// MARK: - Pending Request Row

private struct PendingRequestRow: View {
    let friend: Friend
    let onAccept: () async -> Void
    let onDecline: () async -> Void

    var body: some View {
        HStack {
            AvatarView(name: friend.displayName)
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName).font(.subheadline.weight(.medium))
                Text(friend.email).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    Task { await onDecline() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)

                Button {
                    Task { await onAccept() }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Add Friend Sheet

private struct AddFriendSheet: View {
    let friendsService: FriendsService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var results: [UserProfile] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var requestSentTo = Set<String>()
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if !hasSearched {
                    ContentUnavailableView(
                        "Pesquisar por email",
                        systemImage: "envelope.badge.person.crop",
                        description: Text("Introduz o email exato de um utilizador.")
                    )
                } else if isSearching {
                    ProgressView("A pesquisar...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: email)
                } else {
                    List(results) { user in
                        HStack {
                            AvatarView(name: user.displayName)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName).font(.subheadline.weight(.medium))
                                Text(user.email).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if requestSentTo.contains(user.uid) {
                                Text("Enviado")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Button("Adicionar") {
                                    Task { await sendRequest(to: user) }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Adicionar amigo")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $email, prompt: "Email do utilizador...")
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .onChange(of: email) { scheduleSearch() }
            .alert("Erro", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []; hasSearched = false; return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            isSearching = true
            hasSearched = true
            do {
                results = try await friendsService.searchUsers(email: email.trimmingCharacters(in: .whitespaces))
            } catch {
                results = []
            }
            isSearching = false
        }
    }

    private func sendRequest(to user: UserProfile) async {
        do {
            try await friendsService.sendRequest(to: user)
            requestSentTo.insert(user.uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Avatar

struct AvatarView: View {
    let name: String

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Color.accentColor, in: .circle)
    }
}
