import Foundation

struct IndexResponse<T: Codable>: Codable {
    let total: Int
    let type: String
    let values: [T]
}

enum IndexService {
    static func fetchKeywords() async throws -> [String] {
        let response: IndexResponse<String> = try await APIClient.fetch("/index/keywords")
        return response.values.sorted()
    }

    static func fetchDomains() async throws -> [String] {
        let response: IndexResponse<String> = try await APIClient.fetch("/index/domains")
        return response.values.sorted()
    }

    static func fetchRarities() async throws -> [String] {
        let response: IndexResponse<String> = try await APIClient.fetch("/index/rarities")
        return response.values
    }

    static func fetchTypes() async throws -> [String] {
        let response: IndexResponse<String> = try await APIClient.fetch("/index/card-types")
        return response.values
    }

    static func fetchSupertypes() async throws -> [String] {
        let response: IndexResponse<String> = try await APIClient.fetch("/index/card-supertypes")
        return response.values
    }

    static func fetchEnergyCosts() async throws -> [Int] {
        let response: IndexResponse<Int> = try await APIClient.fetch("/index/energy")
        return response.values.sorted()
    }

    static func fetchTags() async throws -> [String] {
        let response: IndexResponse<String> = try await APIClient.fetch("/index/tags")
        return response.values.sorted()
    }
}
