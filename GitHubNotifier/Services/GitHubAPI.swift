import Foundation

class GitHubAPI {
    private let baseURL = "https://api.github.com"
    private var token: String

    init(token: String) {
        self.token = token
    }

    func fetchNotifications() async throws -> [GitHubNotification] {
        let endpoint = "\(baseURL)/notifications"
        let data = try await makeRequest(endpoint: endpoint)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([GitHubNotification].self, from: data)
    }

    func markNotificationAsRead(threadId: String) async throws {
        let endpoint = "\(baseURL)/notifications/threads/\(threadId)"
        _ = try await makeRequest(endpoint: endpoint, method: "PATCH")
    }

    func markAllNotificationsAsRead() async throws {
        let endpoint = "\(baseURL)/notifications"
        _ = try await makeRequest(endpoint: endpoint, method: "PUT")
    }

    func fetchPullRequest(owner: String, repo: String, number: Int) async throws -> PullRequest {
        let endpoint = "\(baseURL)/repos/\(owner)/\(repo)/pull/\(number)"
        let data = try await makeRequest(endpoint: endpoint)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PullRequest.self, from: data)
    }

    func fetchIssue(owner: String, repo: String, number: Int) async throws -> Issue {
        let endpoint = "\(baseURL)/repos/\(owner)/\(repo)/issue/\(number)"
        let data = try await makeRequest(endpoint: endpoint)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Issue.self, from: data)
    }

    private func makeRequest(endpoint: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.httpBody = body
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Handle rate limiting
        if httpResponse.statusCode == 403 || httpResponse.statusCode == 429 {
            if let resetHeader = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset"),
               let resetTimestamp = TimeInterval(resetHeader) {
                let resetDate = Date(timeIntervalSince1970: resetTimestamp)
                throw APIError.rateLimited(resetTime: resetDate)
            }
            // Check if it's a rate limit error from response body
            if let remaining = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
               remaining == "0" {
                throw APIError.rateLimited(resetTime: nil)
            }
        }

        // Handle unauthorized
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return data
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case unauthorized
    case rateLimited(resetTime: Date?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized. Please check your GitHub token."
        case .rateLimited(let resetTime):
            if let resetTime = resetTime {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                let relativeTime = formatter.localizedString(for: resetTime, relativeTo: Date())
                return "Rate limit exceeded. Resets \(relativeTime)."
            }
            return "Rate limit exceeded. Please try again later."
        }
    }
}
