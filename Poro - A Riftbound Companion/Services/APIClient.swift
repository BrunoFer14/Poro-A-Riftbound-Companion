import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválido."
        case .networkError(let e):
            return "Erro de rede: \(e.localizedDescription)"
        case .decodingError(let e):
            return "Erro ao processar dados: \(e.localizedDescription)"
        case .serverError(let code):
            return "Erro do servidor (\(code))."
        }
    }
}

enum APIClient {
    static let baseURL = "https://api.riftcodex.com"

    private static let decoder = JSONDecoder()

    static func fetch<T: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        var components = URLComponents(string: baseURL + path)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIError.serverError(code)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
