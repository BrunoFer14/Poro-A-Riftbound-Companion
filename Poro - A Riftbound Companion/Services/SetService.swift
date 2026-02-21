import Foundation

enum SetService {
    static func fetchSets(page: Int = 1, size: Int = 100) async throws -> PaginatedResponse<CardSetDetail> {
        try await APIClient.fetch("/sets", queryItems: [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(size)")
        ])
    }

    static func fetchSet(id: String) async throws -> CardSetDetail {
        try await APIClient.fetch("/sets/\(id)")
    }
}
