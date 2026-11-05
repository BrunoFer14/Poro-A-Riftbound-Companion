import Foundation
import FirebaseFirestore

@Observable
final class FriendsService {
    private(set) var friends: [Friend] = []
    private(set) var isLoading = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var uid: String?

    // MARK: - Lifecycle

    func start(uid: String) {
        guard self.uid != uid else { return }
        self.uid = uid
        attachListener(uid: uid)
    }

    func stop() {
        listener?.remove()
        listener = nil
        uid = nil
        friends = []
    }

    // MARK: - Real-time listener

    private func attachListener(uid: String) {
        listener?.remove()
        listener = db.collection("users").document(uid).collection("friends")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let docs = snapshot?.documents else { return }
                self.friends = docs.compactMap { Self.friendFrom(doc: $0) }
            }
    }

    // MARK: - Search

    func searchUsers(email: String) async throws -> [UserProfile] {
        guard let uid else { return [] }
        return try await FirestoreService.searchUsers(byEmail: email, excludingUid: uid)
    }

    // MARK: - Send request

    func sendRequest(to user: UserProfile) async throws {
        guard let uid else { return }
        let myProfile = try await fetchMyProfile(uid: uid)
        let batch = db.batch()

        // My side: initiator = true, pending
        let myRef = db.collection("users").document(uid)
            .collection("friends").document(user.uid)
        batch.setData([
            "displayName": user.displayName,
            "email": user.email,
            "status": "pending",
            "initiator": true,
            "since": FieldValue.serverTimestamp()
        ], forDocument: myRef)

        // Their side: initiator = false, pending
        let theirRef = db.collection("users").document(user.uid)
            .collection("friends").document(uid)
        batch.setData([
            "displayName": myProfile.displayName,
            "email": myProfile.email,
            "status": "pending",
            "initiator": false,
            "since": FieldValue.serverTimestamp()
        ], forDocument: theirRef)

        try await batch.commit()
    }

    // MARK: - Accept request

    func acceptRequest(from friendUid: String) async throws {
        guard let uid else { return }
        let batch = db.batch()

        let myRef = db.collection("users").document(uid)
            .collection("friends").document(friendUid)
        batch.updateData(["status": "accepted"], forDocument: myRef)

        let theirRef = db.collection("users").document(friendUid)
            .collection("friends").document(uid)
        batch.updateData(["status": "accepted"], forDocument: theirRef)

        try await batch.commit()
    }

    // MARK: - Decline / Remove

    func removeFriend(_ friendUid: String) async throws {
        guard let uid else { return }
        let batch = db.batch()
        batch.deleteDocument(db.collection("users").document(uid).collection("friends").document(friendUid))
        batch.deleteDocument(db.collection("users").document(friendUid).collection("friends").document(uid))
        try await batch.commit()
    }

    // MARK: - Friend's collection (read-only)

    func fetchCollection(of friendUid: String, cache: CardCache) async throws -> [CollectionEntry] {
        await cache.loadIfNeeded()
        let snapshot = try await db.collection("users").document(friendUid).collection("collection").getDocuments()
        return snapshot.documents.compactMap { doc -> CollectionEntry? in
            let data = doc.data()
            guard let cardId = data["cardId"] as? String,
                  let card = cache.allCards.first(where: { $0.id == cardId })
            else { return nil }
            let qty = data["quantity"] as? Int ?? 0
            let foil = data["foilQuantity"] as? Int ?? 0
            let promo = data["promoQuantity"] as? Int ?? 0
            guard qty + foil + promo > 0 else { return nil }
            return CollectionEntry(card: card, quantity: qty, foilQuantity: foil, promoQuantity: promo)
        }
    }

    // MARK: - Helpers

    private func fetchMyProfile(uid: String) async throws -> UserProfile {
        let doc = try await db.collection("users").document(uid).getDocument()
        let name = doc["displayName"] as? String ?? "Utilizador"
        let email = doc["email"] as? String ?? ""
        return UserProfile(uid: uid, displayName: name, email: email)
    }

    private static func friendFrom(doc: QueryDocumentSnapshot) -> Friend? {
        let data = doc.data()
        guard let displayName = data["displayName"] as? String,
              let email = data["email"] as? String,
              let statusRaw = data["status"] as? String,
              let status = FriendStatus(rawValue: statusRaw)
        else { return nil }
        let initiator = data["initiator"] as? Bool ?? true
        return Friend(uid: doc.documentID, displayName: displayName, email: email, status: status, initiator: initiator)
    }
}
