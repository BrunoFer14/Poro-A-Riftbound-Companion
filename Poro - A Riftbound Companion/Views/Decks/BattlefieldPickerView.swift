import SwiftUI

struct BattlefieldPickerView: View {
    @Binding var battlefields: [Card]
    let collectionStore: CollectionStore

    @Environment(\.dismiss) private var dismiss

    private var availableBattlefields: [Card] {
        collectionStore.entries
            .map(\.card)
            .filter { $0.classification.type == "Battlefield" }
            .sorted { $0.name < $1.name }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if availableBattlefields.isEmpty {
                    ContentUnavailableView(
                        "Sem battlefields",
                        systemImage: "map",
                        description: Text("Adiciona battlefields à tua coleção primeiro.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(availableBattlefields) { card in
                            let isSelected = battlefields.contains { $0.id == card.id }
                            let canSelect = battlefields.count < 3

                            Button {
                                if isSelected {
                                    battlefields.removeAll { $0.id == card.id }
                                } else if canSelect {
                                    battlefields.append(card)
                                }
                            } label: {
                                BattlefieldCell(card: card, isSelected: isSelected, canSelect: canSelect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Battlefields (\(battlefields.count)/3)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

private struct BattlefieldCell: View {
    let card: Card
    let isSelected: Bool
    let canSelect: Bool

    var body: some View {
        VStack(spacing: 6) {
            CardImageView(url: card.media.imageUrl, width: 100, height: 140)
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .background(Circle().fill(.green).padding(2))
                            .padding(6)
                    }
                }
                .opacity(!isSelected && !canSelect ? 0.4 : 1)

            Text(card.name)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
    }
}
