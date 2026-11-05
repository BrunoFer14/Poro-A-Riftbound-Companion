import Foundation

// MARK: - Card Condition

enum CardCondition: String, CaseIterable, Codable, Identifiable {
    case nearMint = "NM"
    case lightlyPlayed = "LP"
    case moderatelyPlayed = "MP"
    case heavilyPlayed = "HP"
    case damaged = "DM"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nearMint: "Near Mint"
        case .lightlyPlayed: "Lightly Played"
        case .moderatelyPlayed: "Moderately Played"
        case .heavilyPlayed: "Heavily Played"
        case .damaged: "Danificada"
        }
    }

    var color: String {
        switch self {
        case .nearMint: "green"
        case .lightlyPlayed: "yellow"
        case .moderatelyPlayed: "orange"
        case .heavilyPlayed: "red"
        case .damaged: "gray"
        }
    }
}

// MARK: - Listing Status

enum ListingStatus: String, Codable {
    case active
    case sold
    case cancelled
}

// MARK: - Listing

struct Listing: Identifiable, Codable, Hashable {
    let id: String
    let sellerId: String
    let sellerName: String
    let cardId: String
    let cardName: String
    let cardImageUrl: String
    let cardSet: String
    let cardRarity: String
    let cardType: String
    let price: Double          // in euros
    let condition: CardCondition
    let quantity: Int
    let description: String
    let location: String
    let latitude: Double?
    let longitude: Double?
    let createdAt: Date
    var status: ListingStatus

    var formattedPrice: String {
        String(format: "%.2f €", price)
    }
}

// MARK: - Conversation

struct Conversation: Identifiable, Codable, Hashable {
    let id: String
    let listingId: String
    let listingCardName: String
    let listingCardImageUrl: String
    let listingPrice: Double
    let buyerId: String
    let buyerName: String
    let sellerId: String
    let sellerName: String
    var lastMessage: String
    var lastMessageAt: Date
    var unreadCount: [String: Int]  // uid → unread count

    func otherUserName(currentUserId: String) -> String {
        currentUserId == buyerId ? sellerName : buyerName
    }

    func unread(for uid: String) -> Int {
        unreadCount[uid] ?? 0
    }
}

// MARK: - Message

struct Message: Identifiable, Codable {
    let id: String
    let senderId: String
    let senderName: String
    let text: String
    let sentAt: Date
}
