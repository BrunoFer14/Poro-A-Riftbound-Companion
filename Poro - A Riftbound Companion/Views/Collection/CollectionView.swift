import SwiftUI

enum CollectionSortOption: String, CaseIterable {
    case name = "Nome"
    case runeCost = "Rune Cost"
    case domain = "Domínio"
    case rarity = "Raridade"
}

struct CollectionView: View {
    let authService: AuthService
    let collectionStore: CollectionStore
    let cardCache: CardCache

    @State private var showResetPicker = false
    @State private var setToReset: String? = nil // stores setId

    /// Set IDs derived from collection entries (what the user owns).
    private var ownedSetIds: [(setId: String, name: String)] {
        var seen = Set<String>()
        return collectionStore.entries
            .filter { seen.insert($0.card.set.setId).inserted }
            .map { (setId: $0.card.set.setId, name: $0.card.set.label) }
            .sorted { $0.name < $1.name }
    }

    /// All sets from cache (for browsing sets you don't own yet).
    private var allSetsFromCache: [(setId: String, name: String)] {
        guard cardCache.isLoaded else { return [] }
        let owned = Set(collectionStore.entries.map { $0.card.set.setId })
        return cardCache.setInfos.filter { !owned.contains($0.setId) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if collectionStore.entries.isEmpty && !cardCache.isLoaded {
                    ContentUnavailableView(
                        "Coleção vazia",
                        systemImage: "rectangle.stack.badge.plus",
                        description: Text("Adiciona cartas à tua coleção no separador Cartas.")
                    )
                } else {
                    List {
                        // "Todas" folder
                        NavigationLink(value: CollectionFolder.all) {
                            folderRow(
                                name: "Todas",
                                icon: "rectangle.stack.fill",
                                detail: collectionStore.entries.isEmpty ? nil : "\(collectionStore.entries.count) carta(s)"
                            )
                        }

                        // Owned sets
                        if !ownedSetIds.isEmpty {
                            Section {
                                ForEach(ownedSetIds, id: \.setId) { info in
                                    NavigationLink(value: CollectionFolder.set(info.setId)) {
                                        let count = collectionStore.entries.filter { $0.card.set.setId == info.setId }.count
                                        folderRow(
                                            name: info.name,
                                            icon: "folder.fill",
                                            detail: "\(count) carta(s)"
                                        )
                                    }
                                }
                            } header: {
                                Text("Na coleção")
                            }
                        }

                        // Browse all sets (from cache)
                        if !allSetsFromCache.isEmpty {
                            Section {
                                ForEach(allSetsFromCache, id: \.setId) { info in
                                    NavigationLink(value: CollectionFolder.set(info.setId)) {
                                        folderRow(
                                            name: info.name,
                                            icon: "folder",
                                            detail: nil
                                        )
                                    }
                                }
                            } header: {
                                Text("Explorar")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Coleção")
            .toolbar {
                if !ownedSetIds.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showResetPicker = true
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $showResetPicker) {
                resetPickerSheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .confirmationDialog(
                "Repor expansão",
                isPresented: Binding(
                    get: { setToReset != nil },
                    set: { if !$0 { setToReset = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let setId = setToReset {
                    Button("Repor \(setDisplayName(setId))", role: .destructive) {
                        collectionStore.resetSet(setId)
                        setToReset = nil
                    }
                    Button("Cancelar", role: .cancel) {
                        setToReset = nil
                    }
                }
            } message: {
                if let setId = setToReset {
                    Text("Todas as cartas de \(setDisplayName(setId)) serão removidas da coleção. Esta ação não pode ser revertida.")
                }
            }
            .navigationDestination(for: CollectionFolder.self) { folder in
                switch folder {
                case .all:
                    CollectionSetView(authService: authService, collectionStore: collectionStore, cardCache: cardCache, setId: nil)
                case .set(let setId):
                    CollectionSetView(authService: authService, collectionStore: collectionStore, cardCache: cardCache, setId: setId)
                }
            }
        }
        .task {
            await cardCache.loadIfNeeded()
        }
    }

    // MARK: - Folder Row

    private func folderRow(name: String, icon: String, detail: String?) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            Text(name)
                .font(.body)

            Spacer()

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Reset Picker Sheet

    private var resetPickerSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ownedSetIds, id: \.setId) { info in
                        Button {
                            showResetPicker = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                setToReset = info.setId
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(info.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    let count = collectionStore.entries.filter { $0.card.set.setId == info.setId }.count
                                    Text("\(count) carta(s) na coleção")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                } header: {
                    Text("Escolhe a expansão a repor")
                } footer: {
                    Text("Todas as cartas da expansão selecionada serão removidas da coleção.")
                }
            }
            .navigationTitle("Repor Expansão")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showResetPicker = false }
                }
            }
        }
    }

    private func setDisplayName(_ setId: String) -> String {
        ownedSetIds.first { $0.setId == setId }?.name
            ?? cardCache.setInfos.first { $0.setId == setId }?.name
            ?? setId
    }
}

// MARK: - Folder Navigation Value

enum CollectionFolder: Hashable {
    case all
    case set(String) // stores setId
}
