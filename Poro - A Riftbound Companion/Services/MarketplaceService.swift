import Foundation
import FirebaseFirestore

enum MarketplaceService {
    private static let db = Firestore.firestore()
    private static var listingsRef: CollectionReference { db.collection("listings") }
    private static var conversationsRef: CollectionReference { db.collection("conversations") }

    // MARK: - Listings

    static func createListing(_ listing: Listing) async throws {
        let data: [String: Any] = [
            "id": listing.id,
            "sellerId": listing.sellerId,
            "sellerName": listing.sellerName,
            "cardId": listing.cardId,
            "cardName": listing.cardName,
            "cardImageUrl": listing.cardImageUrl,
            "cardSet": listing.cardSet,
            "cardRarity": listing.cardRarity,
            "cardType": listing.cardType,
            "price": listing.price,
            "condition": listing.condition.rawValue,
            "quantity": listing.quantity,
            "description": listing.description,
            "location": listing.location,
            "latitude": listing.latitude as Any,
            "longitude": listing.longitude as Any,
            "createdAt": Timestamp(date: listing.createdAt),
            "status": listing.status.rawValue
        ]
        try await listingsRef.document(listing.id).setData(data)
    }

    static func updateListingStatus(id: String, status: ListingStatus) async throws {
        try await listingsRef.document(id).updateData(["status": status.rawValue])
    }

    static func deleteListing(id: String) async throws {
        try await listingsRef.document(id).delete()
    }

    static func fetchActiveListings(setFilter: String? = nil, maxPrice: Double? = nil) async throws -> [Listing] {
        var query: Query = listingsRef
            .whereField("status", isEqualTo: ListingStatus.active.rawValue)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)

        if let set = setFilter {
            query = listingsRef
                .whereField("status", isEqualTo: ListingStatus.active.rawValue)
                .whereField("cardSet", isEqualTo: set)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
        }

        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { parseListing($0) }
    }

    static func fetchMyListings(sellerId: String) async throws -> [Listing] {
        let snapshot = try await listingsRef
            .whereField("sellerId", isEqualTo: sellerId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { parseListing($0) }
    }

    static func searchListings(query: String) async throws -> [Listing] {
        // Firestore doesn't support full-text search natively.
        // We fetch active listings and filter locally.
        let snapshot = try await listingsRef
            .whereField("status", isEqualTo: ListingStatus.active.rawValue)
            .order(by: "createdAt", descending: true)
            .limit(to: 200)
            .getDocuments()
        return snapshot.documents
            .compactMap { parseListing($0) }
            .filter { $0.cardName.localizedCaseInsensitiveContains(query) }
    }

    static func parseListing(_ doc: QueryDocumentSnapshot) -> Listing? {
        let data = doc.data()
        guard
            let id = data["id"] as? String,
            let sellerId = data["sellerId"] as? String,
            let sellerName = data["sellerName"] as? String,
            let cardId = data["cardId"] as? String,
            let cardName = data["cardName"] as? String,
            let cardImageUrl = data["cardImageUrl"] as? String,
            let cardSet = data["cardSet"] as? String,
            let cardRarity = data["cardRarity"] as? String,
            let cardType = data["cardType"] as? String,
            let price = data["price"] as? Double,
            let conditionRaw = data["condition"] as? String,
            let condition = CardCondition(rawValue: conditionRaw),
            let quantity = data["quantity"] as? Int,
            let createdAt = data["createdAt"] as? Timestamp,
            let statusRaw = data["status"] as? String,
            let status = ListingStatus(rawValue: statusRaw)
        else { return nil }

        return Listing(
            id: id,
            sellerId: sellerId,
            sellerName: sellerName,
            cardId: cardId,
            cardName: cardName,
            cardImageUrl: cardImageUrl,
            cardSet: cardSet,
            cardRarity: cardRarity,
            cardType: cardType,
            price: price,
            condition: condition,
            quantity: quantity,
            description: data["description"] as? String ?? "",
            location: data["location"] as? String ?? "",
            latitude: data["latitude"] as? Double,
            longitude: data["longitude"] as? Double,
            createdAt: createdAt.dateValue(),
            status: status
        )
    }

    // MARK: - Conversations

    static func getOrCreateConversation(
        listing: Listing,
        buyerId: String,
        buyerName: String
    ) async throws -> Conversation {
        let convId = "\(listing.id)_\(buyerId)"

        let existing = try await conversationsRef.document(convId).getDocument()
        if existing.exists, let conv = parseConversation(existing) {
            return conv
        }

        let conv = Conversation(
            id: convId,
            listingId: listing.id,
            listingCardName: listing.cardName,
            listingCardImageUrl: listing.cardImageUrl,
            listingPrice: listing.price,
            buyerId: buyerId,
            buyerName: buyerName,
            sellerId: listing.sellerId,
            sellerName: listing.sellerName,
            lastMessage: "",
            lastMessageAt: Date(),
            unreadCount: [:]
        )
        try await saveConversation(conv)
        return conv
    }

    static func fetchConversations(userId: String) async throws -> [Conversation] {
        // Fetch as buyer
        let buyerSnap = try await conversationsRef
            .whereField("buyerId", isEqualTo: userId)
            .order(by: "lastMessageAt", descending: true)
            .getDocuments()

        // Fetch as seller
        let sellerSnap = try await conversationsRef
            .whereField("sellerId", isEqualTo: userId)
            .order(by: "lastMessageAt", descending: true)
            .getDocuments()

        let all = (buyerSnap.documents + sellerSnap.documents)
            .compactMap { parseConversation($0) }

        // Deduplicate and sort
        var seen = Set<String>()
        return all
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    static func sendMessage(
        conversationId: String,
        message: Message,
        conversation: Conversation,
        currentUserId: String
    ) async throws {
        let msgData: [String: Any] = [
            "id": message.id,
            "senderId": message.senderId,
            "senderName": message.senderName,
            "text": message.text,
            "sentAt": Timestamp(date: message.sentAt)
        ]
        try await conversationsRef
            .document(conversationId)
            .collection("messages")
            .document(message.id)
            .setData(msgData)

        // Update conversation metadata
        let otherId = currentUserId == conversation.buyerId ? conversation.sellerId : conversation.buyerId
        try await conversationsRef.document(conversationId).updateData([
            "lastMessage": message.text,
            "lastMessageAt": Timestamp(date: message.sentAt),
            "unreadCount.\(otherId)": FieldValue.increment(Int64(1))
        ])
    }

    static func fetchMessages(conversationId: String) async throws -> [Message] {
        let snapshot = try await conversationsRef
            .document(conversationId)
            .collection("messages")
            .order(by: "sentAt")
            .getDocuments()
        return snapshot.documents.compactMap { parseMessage($0) }
    }

    static func markAsRead(conversationId: String, userId: String) async throws {
        try await conversationsRef.document(conversationId).updateData([
            "unreadCount.\(userId)": 0
        ])
    }

    // MARK: - Parse helpers

    static func saveConversation(_ conv: Conversation) async throws {
        let data: [String: Any] = [
            "id": conv.id,
            "listingId": conv.listingId,
            "listingCardName": conv.listingCardName,
            "listingCardImageUrl": conv.listingCardImageUrl,
            "listingPrice": conv.listingPrice,
            "buyerId": conv.buyerId,
            "buyerName": conv.buyerName,
            "sellerId": conv.sellerId,
            "sellerName": conv.sellerName,
            "lastMessage": conv.lastMessage,
            "lastMessageAt": Timestamp(date: conv.lastMessageAt),
            "unreadCount": conv.unreadCount
        ]
        try await conversationsRef.document(conv.id).setData(data)
    }

    static func parseConversation(_ doc: DocumentSnapshot) -> Conversation? {
        let data = doc.data() ?? [:]
        guard
            let id = data["id"] as? String,
            let listingId = data["listingId"] as? String,
            let listingCardName = data["listingCardName"] as? String,
            let listingCardImageUrl = data["listingCardImageUrl"] as? String,
            let listingPrice = data["listingPrice"] as? Double,
            let buyerId = data["buyerId"] as? String,
            let buyerName = data["buyerName"] as? String,
            let sellerId = data["sellerId"] as? String,
            let sellerName = data["sellerName"] as? String,
            let lastMessageAt = data["lastMessageAt"] as? Timestamp
        else { return nil }

        return Conversation(
            id: id,
            listingId: listingId,
            listingCardName: listingCardName,
            listingCardImageUrl: listingCardImageUrl,
            listingPrice: listingPrice,
            buyerId: buyerId,
            buyerName: buyerName,
            sellerId: sellerId,
            sellerName: sellerName,
            lastMessage: data["lastMessage"] as? String ?? "",
            lastMessageAt: lastMessageAt.dateValue(),
            unreadCount: data["unreadCount"] as? [String: Int] ?? [:]
        )
    }

    static func parseMessage(_ doc: QueryDocumentSnapshot) -> Message? {
        let data = doc.data()
        guard
            let id = data["id"] as? String,
            let senderId = data["senderId"] as? String,
            let senderName = data["senderName"] as? String,
            let text = data["text"] as? String,
            let sentAt = data["sentAt"] as? Timestamp
        else { return nil }

        return Message(
            id: id,
            senderId: senderId,
            senderName: senderName,
            text: text,
            sentAt: sentAt.dateValue()
        )
    }
}
