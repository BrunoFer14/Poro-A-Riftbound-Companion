import Foundation

struct CardFilter: Equatable {
    var selectedDomains: Set<String> = []
    var selectedEnergyCosts: Set<Int> = []
    var selectedSets: Set<String> = []

    var isActive: Bool {
        !selectedDomains.isEmpty || !selectedEnergyCosts.isEmpty || !selectedSets.isEmpty
    }

    func matches(_ card: Card) -> Bool {
        if !selectedDomains.isEmpty {
            let cardDomains = Set(card.classification.domain)
            if cardDomains.isDisjoint(with: selectedDomains) {
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
    }
}
