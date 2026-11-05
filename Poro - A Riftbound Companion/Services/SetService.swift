import Foundation

enum SetService {
    static func fetchSets() async throws -> [CardSetDetail] {
        let response: RiftHuntList<CardSetDetail> = try await APIClient.fetch("/sets")
        return response.data
    }
}
