import Foundation
import FirebaseFirestore

// MARK: - User Profile

struct UserProfile: Identifiable, Hashable {
    let uid: String
    let displayName: String
    let email: String
    var id: String { uid }
}

// MARK: - Friend

struct Friend: Identifiable, Hashable {
    let uid: String
    let displayName: String
    let email: String
    let status: FriendStatus
    let initiator: Bool   // true = this user sent the request
    var id: String { uid }
}

enum FriendStatus: String {
    case pending, accepted
}

// MARK: - Firestore DTOs

struct FirestoreCollectionEntry: Codable {
    let cardId: String
    let quantity: Int
    let foilQuantity: Int
    let promoQuantity: Int
    let addedAt: Date
}

struct FirestoreDeckEntry: Codable {
    let cardId: String
    let quantity: Int
}

struct FirestoreDeck: Codable {
    let id: String
    let name: String
    let legendCardId: String
    let entries: [FirestoreDeckEntry]
    let battlefieldCardIds: [String]
    let runes: [String: Int]
    let createdAt: Date
}

// MARK: - Firestore Service

enum FirestoreService {
    private static let db = Firestore.firestore()

    private static func userRef(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    // MARK: - User Profile

    static func saveUserProfile(uid: String, displayName: String, email: String) async throws {
        let data: [String: Any] = [
            "displayName": displayName,
            "email": email,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await userRef(uid).setData(data, merge: true)
    }

    static func searchUsers(byEmail email: String, excludingUid: String) async throws -> [UserProfile] {
        let snapshot = try await db.collection("users")
            .whereField("email", isEqualTo: email.lowercased())
            .limit(to: 10)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            guard doc.documentID != excludingUid,
                  let name = doc["displayName"] as? String,
                  let mail = doc["email"] as? String
            else { return nil }
            return UserProfile(uid: doc.documentID, displayName: name, email: mail)
        }
    }

    private static func collectionRef(_ uid: String) -> CollectionReference {
        userRef(uid).collection("collection")
    }

    private static func decksRef(_ uid: String) -> CollectionReference {
        userRef(uid).collection("decks")
    }

    // MARK: - Collection

    static func saveCollectionEntry(uid: String, cardId: String, quantity: Int, foilQuantity: Int = 0, promoQuantity: Int = 0) async throws {
        let data: [String: Any] = [
            "cardId": cardId,
            "quantity": quantity,
            "foilQuantity": foilQuantity,
            "promoQuantity": promoQuantity,
            "addedAt": FieldValue.serverTimestamp()
        ]
        try await collectionRef(uid).document(cardId).setData(data)
    }

    static func deleteCollectionEntry(uid: String, cardId: String) async throws {
        try await collectionRef(uid).document(cardId).delete()
    }

    static func uploadCollection(uid: String, entries: [CollectionEntry]) async throws {
        let batch = db.batch()
        let ref = collectionRef(uid)

        // Delete existing entries first
        let existing = try await ref.getDocuments()
        for doc in existing.documents {
            batch.deleteDocument(doc.reference)
        }

        // Write new entries
        for entry in entries {
            let docRef = ref.document(entry.card.id)
            let data: [String: Any] = [
                "cardId": entry.card.id,
                "quantity": entry.quantity,
                "foilQuantity": entry.foilQuantity,
                "promoQuantity": entry.promoQuantity,
                "addedAt": FieldValue.serverTimestamp()
            ]
            batch.setData(data, forDocument: docRef)
        }

        try await batch.commit()
    }

    static func downloadCollection(uid: String) async throws -> [FirestoreCollectionEntry] {
        let snapshot = try await collectionRef(uid).getDocuments()
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let cardId = data["cardId"] as? String,
                  let quantity = data["quantity"] as? Int
            else { return nil }
            let foilQuantity = data["foilQuantity"] as? Int ?? 0
            let promoQuantity = data["promoQuantity"] as? Int ?? 0
            let addedAt = (data["addedAt"] as? Timestamp)?.dateValue() ?? Date()
            return FirestoreCollectionEntry(cardId: cardId, quantity: quantity, foilQuantity: foilQuantity, promoQuantity: promoQuantity, addedAt: addedAt)
        }
    }

    // MARK: - Decks

    static func saveDeck(uid: String, deck: Deck) async throws {
        let entriesData = deck.entries.map { entry in
            ["cardId": entry.card.id, "quantity": entry.quantity] as [String: Any]
        }
        let data: [String: Any] = [
            "id": deck.id.uuidString,
            "name": deck.name,
            "legendCardId": deck.legend.id,
            "entries": entriesData,
            "battlefieldCardIds": deck.battlefields.map(\.id),
            "runes": deck.runes,
            "createdAt": Timestamp(date: deck.createdAt)
        ]
        try await decksRef(uid).document(deck.id.uuidString).setData(data)
    }

    static func deleteDeck(uid: String, deckId: UUID) async throws {
        try await decksRef(uid).document(deckId.uuidString).delete()
    }

    static func uploadDecks(uid: String, decks: [Deck]) async throws {
        let batch = db.batch()
        let ref = decksRef(uid)

        let existing = try await ref.getDocuments()
        for doc in existing.documents {
            batch.deleteDocument(doc.reference)
        }

        for deck in decks {
            let docRef = ref.document(deck.id.uuidString)
            let entriesData = deck.entries.map { entry in
                ["cardId": entry.card.id, "quantity": entry.quantity] as [String: Any]
            }
            let data: [String: Any] = [
                "id": deck.id.uuidString,
                "name": deck.name,
                "legendCardId": deck.legend.id,
                "entries": entriesData,
                "battlefieldCardIds": deck.battlefields.map(\.id),
                "runes": deck.runes,
                "createdAt": Timestamp(date: deck.createdAt)
            ]
            batch.setData(data, forDocument: docRef)
        }

        try await batch.commit()
    }

    static func downloadDecks(uid: String) async throws -> [FirestoreDeck] {
        let snapshot = try await decksRef(uid).getDocuments()
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let id = data["id"] as? String,
                  let name = data["name"] as? String,
                  let legendCardId = data["legendCardId"] as? String,
                  let entriesArray = data["entries"] as? [[String: Any]],
                  let createdAt = data["createdAt"] as? Timestamp
            else { return nil }

            let entries = entriesArray.compactMap { entryData -> FirestoreDeckEntry? in
                guard let cardId = entryData["cardId"] as? String,
                      let quantity = entryData["quantity"] as? Int
                else { return nil }
                return FirestoreDeckEntry(cardId: cardId, quantity: quantity)
            }

            // Support both old "locationCardIds" and new "battlefieldCardIds"
            let battlefieldCardIds = (data["battlefieldCardIds"] as? [String])
                ?? (data["locationCardIds"] as? [String])
                ?? []
            let runes = (data["runes"] as? [String: Int]) ?? [:]

            return FirestoreDeck(
                id: id,
                name: name,
                legendCardId: legendCardId,
                entries: entries,
                battlefieldCardIds: battlefieldCardIds,
                runes: runes,
                createdAt: createdAt.dateValue()
            )
        }
    }
}
