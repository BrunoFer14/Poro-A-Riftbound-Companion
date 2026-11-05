import Foundation

struct CardFilter: Equatable {
    var selectedDomains: Set<String> = []
    var selectedEnergyCosts: Set<Int> = []
    var selectedSets: Set<String> = []
    var selectedTypes: Set<String> = []
    var selectedRarities: Set<String> = []

    var isActive: Bool {
        !selectedDomains.isEmpty || !selectedEnergyCosts.isEmpty ||
        !selectedSets.isEmpty || !selectedTypes.isEmpty || !selectedRarities.isEmpty
    }

    func matches(_ card: Card) -> Bool {
        let isBattlefield = card.classification.type == "Battlefield"

        // Type filter
        if !selectedTypes.isEmpty {
            if !selectedTypes.contains(card.classification.type) {
                return false
            }
        }

        // Rarity filter
        if !selectedRarities.isEmpty {
            if !selectedRarities.contains(card.classification.rarity) {
                return false
            }
        }

        // Domain filter — when "Colorless" is selected, exclude Battlefields
        // (Battlefields have their own type filter)
        if !selectedDomains.isEmpty {
            let cardDomains = Set(card.classification.domain)
            if cardDomains.isDisjoint(with: selectedDomains) {
                return false
            }
            if selectedDomains.contains("Colorless") && isBattlefield && !selectedTypes.contains("Battlefield") {
                return false
            }
        }

        if !selectedEnergyCosts.isEmpty {
            guard let energy = card.attributes.energy else { return false }
            if !selectedEnergyCosts.contains(energy) {
                return false
            }
        }

        if !selectedSets.isEmpty {
            if !selectedSets.contains(card.set.label) {
                return false
            }
        }

        return true
    }

    mutating func reset() {
        selectedDomains = []
        selectedEnergyCosts = []
        selectedSets = []
        selectedTypes = []
        selectedRarities = []
    }
}
