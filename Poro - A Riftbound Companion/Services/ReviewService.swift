import Foundation
import FirebaseFirestore

enum ReviewService {
    private static let db = Firestore.firestore()
    private static var reviewsRef: CollectionReference { db.collection("reviews") }

    static func submitReview(_ review: Review) async throws {
        let data: [String: Any] = [
            "id": review.id,
            "listingId": review.listingId,
            "sellerId": review.sellerId,
            "reviewerId": review.reviewerId,
            "reviewerName": review.reviewerName,
            "rating": review.rating,
            "comment": review.comment,
            "createdAt": Timestamp(date: review.createdAt)
        ]
        try await reviewsRef.document(review.id).setData(data)
    }

    static func fetchReviews(for sellerId: String) async throws -> [Review] {
        let snapshot = try await reviewsRef
            .whereField("sellerId", isEqualTo: sellerId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { parse($0) }
    }

    static func hasReviewed(listingId: String, reviewerId: String) async -> Bool {
        let docId = "\(listingId)_\(reviewerId)"
        let snap = try? await reviewsRef.document(docId).getDocument()
        return snap?.exists == true
    }

    private static func parse(_ doc: QueryDocumentSnapshot) -> Review? {
        let data = doc.data()
        guard
            let id = data["id"] as? String,
            let listingId = data["listingId"] as? String,
            let sellerId = data["sellerId"] as? String,
            let reviewerId = data["reviewerId"] as? String,
            let reviewerName = data["reviewerName"] as? String,
            let rating = data["rating"] as? Int,
            let createdAt = data["createdAt"] as? Timestamp
        else { return nil }

        return Review(
            id: id,
            listingId: listingId,
            sellerId: sellerId,
            reviewerId: reviewerId,
            reviewerName: reviewerName,
            rating: rating,
            comment: data["comment"] as? String ?? "",
            createdAt: createdAt.dateValue()
        )
    }
}
