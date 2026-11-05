import Foundation
import Observation
import CoreLocation
import FirebaseFirestore

@Observable
final class MarketplaceViewModel {
    private(set) var listings: [Listing] = []
    private(set) var myListings: [Listing] = []
    private(set) var conversations: [Conversation] = []
    private(set) var isLoading = false
    private(set) var isLoadingConversations = false
    var errorMessage: String?

    var searchText = ""
    var selectedSet: String? = nil
    var selectedCondition: CardCondition? = nil
    var maxPrice: Double? = nil
    var selectedLocation: String? = nil
    var nearMeEnabled = false
    var nearMeRadiusKm: Double = 25
    var locationService = LocationService()

    private var buyerConvs: [Conversation] = []
    private var sellerConvs: [Conversation] = []
    private var buyerListener: ListenerRegistration?
    private var sellerListener: ListenerRegistration?
    private var currentUserId: String?

    // Stores conversationId → timestamp when hidden
    private var hiddenConversations: [String: Date] {
        get {
            let raw = UserDefaults.standard.dictionary(forKey: "hiddenConversations") as? [String: Double] ?? [:]
            return raw.mapValues { Date(timeIntervalSince1970: $0) }
        }
        set {
            UserDefaults.standard.set(newValue.mapValues { $0.timeIntervalSince1970 }, forKey: "hiddenConversations")
        }
    }

    var availableSets: [String] {
        Array(Set(listings.map { $0.cardSet })).sorted()
    }

    var filteredListings: [Listing] {
        var result = listings
        if !searchText.isEmpty {
            result = result.filter { $0.cardName.localizedCaseInsensitiveContains(searchText) }
        }
        if let set = selectedSet {
            result = result.filter { $0.cardSet == set }
        }
        if let condition = selectedCondition {
            result = result.filter { $0.condition == condition }
        }
        if let max = maxPrice {
            result = result.filter { $0.price <= max }
        }
        if let location = selectedLocation {
            result = result.filter { $0.location.localizedCaseInsensitiveContains(location) }
        }
        if nearMeEnabled, let userLoc = locationService.currentLocation {
            result = result.filter { listing in
                guard let lat = listing.latitude, let lng = listing.longitude else { return false }
                let listingLoc = CLLocation(latitude: lat, longitude: lng)
                return userLoc.distance(from: listingLoc) / 1000 <= nearMeRadiusKm
            }
        }
        return result
    }

    var totalUnread: Int {
        conversations.reduce(0) { $0 + $1.unread(for: currentUserId ?? "") }
    }

    func setup(userId: String) {
        currentUserId = userId
    }

    // MARK: - Listings

    func loadListings() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            listings = try await MarketplaceService.fetchActiveListings(setFilter: selectedSet)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func loadMyListings(sellerId: String) async {
        do {
            myListings = try await MarketplaceService.fetchMyListings(sellerId: sellerId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createListing(_ listing: Listing) async throws {
        try await MarketplaceService.createListing(listing)
        listings.insert(listing, at: 0)
        myListings.insert(listing, at: 0)
    }

    func markAsSold(listing: Listing) async throws {
        try await MarketplaceService.updateListingStatus(id: listing.id, status: .sold)
        updateStatus(listing.id, to: .sold)
    }

    func cancelListing(listing: Listing) async throws {
        try await MarketplaceService.updateListingStatus(id: listing.id, status: .cancelled)
        updateStatus(listing.id, to: .cancelled)
    }

    func deleteListing(listing: Listing) async throws {
        try await MarketplaceService.deleteListing(id: listing.id)
        myListings.removeAll { $0.id == listing.id }
        listings.removeAll { $0.id == listing.id }
    }

    private func updateStatus(_ id: String, to status: ListingStatus) {
        if let i = listings.firstIndex(where: { $0.id == id }) {
            listings[i].status = status
        }
        if let i = myListings.firstIndex(where: { $0.id == id }) {
            myListings[i].status = status
        }
    }

    // MARK: - Conversations (real-time)

    func listenToConversations(userId: String) {
        isLoadingConversations = true
        let db = Firestore.firestore()

        buyerListener = db.collection("conversations")
            .whereField("buyerId", isEqualTo: userId)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                self.buyerConvs = snapshot.documents.compactMap { MarketplaceService.parseConversation($0) }
                self.mergeConversations()
                self.isLoadingConversations = false
            }

        sellerListener = db.collection("conversations")
            .whereField("sellerId", isEqualTo: userId)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                self.sellerConvs = snapshot.documents.compactMap { MarketplaceService.parseConversation($0) }
                self.mergeConversations()
                self.isLoadingConversations = false
            }
    }

    func hideConversation(_ id: String) {
        var hidden = hiddenConversations
        hidden[id] = Date()
        hiddenConversations = hidden
        conversations.removeAll { $0.id == id }
    }

    private func mergeConversations() {
        let hidden = hiddenConversations
        var seen = Set<String>()
        conversations = (buyerConvs + sellerConvs)
            .filter { conv in
                guard seen.insert(conv.id).inserted else { return false }
                // If hidden, reappear only if a new message arrived after hiding
                if let hiddenAt = hidden[conv.id] {
                    return conv.lastMessageAt > hiddenAt
                }
                return true
            }
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    func disconnect() {
        buyerListener?.remove()
        sellerListener?.remove()
        buyerListener = nil
        sellerListener = nil
    }

    func getOrCreateConversation(
        listing: Listing,
        buyerId: String,
        buyerName: String
    ) async throws -> Conversation {
        try await MarketplaceService.getOrCreateConversation(
            listing: listing,
            buyerId: buyerId,
            buyerName: buyerName
        )
    }
}

// MARK: - ConversationViewModel

@Observable
final class ConversationViewModel {
    private(set) var messages: [Message] = []
    private(set) var isLoading = false
    var newMessageText = ""

    private var messagesListener: ListenerRegistration?

    func listenToMessages(conversationId: String, currentUserId: String) {
        isLoading = true
        messagesListener = Firestore.firestore()
            .collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "sentAt")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                self.messages = snapshot.documents.compactMap { MarketplaceService.parseMessage($0) }
                if self.isLoading {
                    self.isLoading = false
                    Task { try? await MarketplaceService.markAsRead(conversationId: conversationId, userId: currentUserId) }
                }
            }
    }

    func stopListening() {
        messagesListener?.remove()
        messagesListener = nil
    }

    func sendMessage(
        conversation: Conversation,
        senderId: String,
        senderName: String
    ) async throws {
        let text = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        newMessageText = ""

        let msg = Message(
            id: UUID().uuidString,
            senderId: senderId,
            senderName: senderName,
            text: text,
            sentAt: Date()
        )

        try await MarketplaceService.sendMessage(
            conversationId: conversation.id,
            message: msg,
            conversation: conversation,
            currentUserId: senderId
        )
    }
}
