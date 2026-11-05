import SwiftUI

struct CardFilterView: View {
    @Binding var filter: CardFilter
    let availableDomains: [String]
    let availableEnergyCosts: [Int]
    var availableTypes: [String] = []
    var availableSets: [String] = []
    var availableRarities: [String] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !availableSets.isEmpty {
                    Section {
                        FlowLayout(spacing: 8) {
                            ForEach(availableSets, id: \.self) { set in
                                FilterChip(
                                    title: set,
                                    isSelected: filter.selectedSets.contains(set)
                                ) {
                                    filter.selectedSets.toggle(set)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    } header: {
                        Text("Expansão")
                    }
                }

                if !availableTypes.isEmpty {
                    Section {
                        FlowLayout(spacing: 8) {
                            ForEach(availableTypes, id: \.self) { type in
                                FilterChip(
                                    title: type,
                                    isSelected: filter.selectedTypes.contains(type)
                                ) {
                                    filter.selectedTypes.toggle(type)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    } header: {
                        Text("Tipo")
                    }
                }

                if !availableRarities.isEmpty {
                    Section {
                        FlowLayout(spacing: 8) {
                            ForEach(availableRarities, id: \.self) { rarity in
                                FilterChip(
                                    title: rarity,
                                    isSelected: filter.selectedRarities.contains(rarity)
                                ) {
                                    filter.selectedRarities.toggle(rarity)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    } header: {
                        Text("Raridade")
                    }
                }

                Section {
                    FlowLayout(spacing: 8) {
                        ForEach(availableDomains, id: \.self) { domain in
                            FilterChip(
                                title: domain,
                                isSelected: filter.selectedDomains.contains(domain)
                            ) {
                                filter.selectedDomains.toggle(domain)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Text("Domínio")
                }

                Section {
                    FlowLayout(spacing: 8) {
                        ForEach(availableEnergyCosts, id: \.self) { cost in
                            FilterChip(
                                title: "\(cost)",
                                isSelected: filter.selectedEnergyCosts.contains(cost)
                            ) {
                                filter.selectedEnergyCosts.toggle(cost)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Text("Custo de Energia")
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Limpar") {
                        filter.reset()
                    }
                    .disabled(!filter.isActive)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Set Toggle Helper

private extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), in: .capsule)
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        computeLayout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height),
            subviews: subviews
        )
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
