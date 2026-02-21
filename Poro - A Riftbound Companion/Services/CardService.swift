import Foundation

enum CardService {
    static func fetchCards(page: Int = 1, size: Int = 50) async throws -> PaginatedResponse<Card> {
        try await APIClient.fetch("/cards", queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
    }

    static func searchCards(query: String, page: Int = 1, size: Int = 50) async throws -> PaginatedResponse<Card> {
        try await APIClient.fetch("/cards/search", queryItems: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
    }

    static func fetchCard(id: String) async throws -> Card {
        try await APIClient.fetch("/cards/\(id)")
    }
}
