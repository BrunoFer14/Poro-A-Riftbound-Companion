import SwiftUI

struct FriendCollectionView: View {
    let friend: Friend
    let cardCache: CardCache

    @State private var entries: [CollectionEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    private let friendsService = FriendsService()

    private var grouped: [(setId: String, name: String)] {
        var seen = Set<String>()
        return entries
            .filter { seen.insert($0.card.set.setId).inserted }
            .map { (setId: $0.card.set.setId, name: $0.card.set.label) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("A carregar coleção...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                ContentUnavailableView(
                    "Erro ao carregar",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if entries.isEmpty {
                ContentUnavailableView(
                    "Coleção vazia",
                    systemImage: "rectangle.stack",
                    description: Text("\(friend.displayName) ainda não tem cartas na coleção.")
                )
            } else {
                List {
                    NavigationLink(value: FriendCollectionFolder.all) {
                        HStack {
                            Image(systemName: "rectangle.stack.fill").foregroundStyle(.tint).frame(width: 28)
                            Text("Todas")
                            Spacer()
                            Text("\(entries.count) carta(s)").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    ForEach(grouped, id: \.setId) { info in
                        NavigationLink(value: FriendCollectionFolder.set(info.setId)) {
                            HStack {
                                Image(systemName: "folder.fill").foregroundStyle(.tint).frame(width: 28)
                                Text(info.name)
                                Spacer()
                                let count = entries.filter { $0.card.set.setId == info.setId }.count
                                Text("\(count) carta(s)").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("\(friend.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: FriendCollectionFolder.self) { folder in
            let filtered: [CollectionEntry] = {
                switch folder {
                case .all: return entries
                case .set(let setId): return entries.filter { $0.card.set.setId == setId }
                }
            }()
            FriendSetView(entries: filtered, cardCache: cardCache)
        }
        .task {
            do {
                entries = try await friendsService.fetchCollection(of: friend.uid, cache: cardCache)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Set grid (read-only)

private struct FriendSetView: View {
    let entries: [CollectionEntry]
    let cardCache: CardCache

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(entries) { entry in
                    NavigationLink(value: entry.card) {
                        VStack(spacing: 6) {
                            CardImageView(url: entry.card.media.imageUrl, width: 100, height: 140)
                                .overlay(alignment: .topTrailing) {
                                    if entry.totalQuantity > 0 {
                                        Text("×\(entry.totalQuantity)")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(.secondary, in: .capsule)
                                            .padding(4)
                                    }
                                }
                            Text(entry.card.name)
                                .font(.caption2)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Coleção")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Card.self) { card in
            // Read-only: pass a no-op store
            CardDetailView(card: card, collectionStore: CollectionStore(), cardCache: cardCache)
        }
    }
}

// MARK: - Navigation value

private enum FriendCollectionFolder: Hashable {
    case all
    case set(String)
}
