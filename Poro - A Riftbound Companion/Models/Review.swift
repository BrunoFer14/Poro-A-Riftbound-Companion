import Foundation

struct Review: Identifiable, Codable, Hashable {
    let id: String          // "{listingId}_{reviewerId}"
    let listingId: String
    let sellerId: String
    let reviewerId: String
    let reviewerName: String
    let rating: Int         // 1–5
    let comment: String
    let createdAt: Date
}
