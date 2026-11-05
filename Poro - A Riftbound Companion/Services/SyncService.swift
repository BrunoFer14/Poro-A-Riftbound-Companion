import Foundation
import FirebaseAuth
import Observation

@Observable
final class SyncService {
    let authService: AuthService
    let collectionStore: CollectionStore
    let deckStore: DeckStore
    let cardCache: CardCache

    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: String?

    init(authService: AuthService, collectionStore: CollectionStore, deckStore: DeckStore, cardCache: CardCache) {
        self.authService = authService
        self.collectionStore = collectionStore
        self.deckStore = deckStore
        self.cardCache = cardCache
    }

    /// Called after login, on foreground, or manually. Merges local + cloud data.
    func performSync() async {
        guard let uid = authService.currentUser?.uid else { return }
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil

        defer { isSyncing = false }

        // Ensure card cache is loaded (needed to resolve IDs)
        await cardCache.loadIfNeeded()

        guard cardCache.isLoaded else {
            syncError = "Não foi possível carregar as cartas. Verifica a tua ligação."
            return
        }

        // Set authUid on stores so write-through kicks in
        collectionStore.authUid = uid
        deckStore.authUid = uid

        do {
            try await mergeCollection(uid: uid)
        } catch {
            syncError = "Erro ao sincronizar coleção: \(error.localizedDescription)"
            #if DEBUG
            print("⚠️ Collection sync error: \(error)")
            #endif
            return
        }

        do {
            try await mergeDecks(uid: uid)
        } catch {
            syncError = "Erro ao sincronizar decks: \(error.localizedDescription)"
            #if DEBUG
            print("⚠️ Deck sync error: \(error)")
            #endif
            return
        }

        lastSyncDate = Date()
    }

    /// Called on sign out — stops write-through.
    func disconnect() {
        collectionStore.authUid = nil
        deckStore.authUid = nil
    }

    // MARK: - Collection Merge

    private func mergeCollection(uid: String) async throws {
        let cloudEntries = try await FirestoreService.downloadCollection(uid: uid)

        // Build lookup from local entries (already have full Card objects)
        var localCardLookup: [String: Card] = [:]
        var mergedQty: [String: Int] = [:]
        var mergedFoilQty: [String: Int] = [:]
        var mergedPromoQty: [String: Int] = [:]

        for entry in collectionStore.entries {
            localCardLookup[entry.card.id] = entry.card
            mergedQty[entry.card.id] = entry.quantity
            mergedFoilQty[entry.card.id] = entry.foilQuantity
            mergedPromoQty[entry.card.id] = entry.promoQuantity
        }

        // Also use cache for cloud-only cards
        let cacheLookup = Dictionary(uniqueKeysWithValues: cardCache.allCards.map { ($0.id, $0) })

        // Cloud entries — take max quantity
        for entry in cloudEntries {
            let currentQty = mergedQty[entry.cardId] ?? 0
            let currentFoil = mergedFoilQty[entry.cardId] ?? 0
            let currentPromo = mergedPromoQty[entry.cardId] ?? 0
            mergedQty[entry.cardId] = max(currentQty, entry.quantity)
            mergedFoilQty[entry.cardId] = max(currentFoil, entry.foilQuantity)
            mergedPromoQty[entry.cardId] = max(currentPromo, entry.promoQuantity)
            if localCardLookup[entry.cardId] == nil {
                localCardLookup[entry.cardId] = cacheLookup[entry.cardId]
            }
        }

        // Resolve — use local Card objects first, then cache
        var resolved: [CollectionEntry] = []
        var unresolvedCount = 0
        for (cardId, quantity) in mergedQty {
            if let card = localCardLookup[cardId] {
                resolved.append(CollectionEntry(card: card, quantity: quantity, foilQuantity: mergedFoilQty[cardId] ?? 0, promoQuantity: mergedPromoQty[cardId] ?? 0))
            } else {
                unresolvedCount += 1
                #if DEBUG
                print("⚠️ Could not resolve card \(cardId) — skipping")
                #endif
            }
        }

        if unresolvedCount > 0 {
            print("⚠️ \(unresolvedCount) card(s) could not be resolved from cache")
        }

        resolved.sort { $0.card.name < $1.card.name }

        // Update local store
        collectionStore.replaceAll(resolved)

        // Upload merged result to Firestore
        try await FirestoreService.uploadCollection(uid: uid, entries: resolved)
    }

    // MARK: - Deck Merge

    private func mergeDecks(uid: String) async throws {
        let cloudDecks = try await FirestoreService.downloadDecks(uid: uid)
        let cardLookup = Dictionary(uniqueKeysWithValues: cardCache.allCards.map { ($0.id, $0) })

        // Local decks keyed by ID
        var localMap: [String: Deck] = [:]
        for deck in deckStore.decks {
            localMap[deck.id.uuidString] = deck
        }

        // Cloud-only decks
        for cloudDeck in cloudDecks {
            if localMap[cloudDeck.id] != nil { continue }

            // Resolve cloud-only deck
            guard let legendCard = cardLookup[cloudDeck.legendCardId],
                  let deckId = UUID(uuidString: cloudDeck.id)
            else { continue }

            var entries: [DeckEntry] = []
            for entry in cloudDeck.entries {
                if let card = cardLookup[entry.cardId] {
                    entries.append(DeckEntry(card: card, quantity: entry.quantity))
                }
            }

            let battlefields = cloudDeck.battlefieldCardIds.compactMap { cardLookup[$0] }

            let deck = Deck(
                id: deckId,
                name: cloudDeck.name,
                legend: legendCard,
                entries: entries,
                battlefields: battlefields,
                runes: cloudDeck.runes,
                createdAt: cloudDeck.createdAt
            )
            localMap[cloudDeck.id] = deck
        }

        // Update local store with all decks
        let allDecks = Array(localMap.values).sorted { $0.createdAt < $1.createdAt }
        deckStore.replaceAll(allDecks)

        // Upload merged result to Firestore
        try await FirestoreService.uploadDecks(uid: uid, decks: allDecks)
    }
}
