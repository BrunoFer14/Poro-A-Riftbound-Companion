import Foundation

enum CardService {
    static func fetchCard(id: String) async throws -> Card {
        try await APIClient.fetch("/cards/\(id)")
    }
}
