//
//  GitHubAPI.swift
//  GitHubNotifier
//
//  REST API client for GitHub notifications management.
//  For PR/Issue details, use GitHubGraphQLClient (richer data).
//

import Foundation

/// REST API client for GitHub notifications management.
///
/// Provides methods for fetching notifications and marking them as read.
/// For detailed PR/Issue information (CI status, reviews), use GitHubGraphQLClient.
public final class GitHubAPI: Sendable {
    private let baseURL = "https://api.github.com"
    private let token: String
    private let session: URLSession

    /// Configured JSON decoder for GitHub API responses.
    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Initializes a new GitHub REST API client.
    ///
    /// - Parameter token: GitHub personal access token for authentication
    public init(token: String) {
        self.token = token

        // GitHub notifications are time-sensitive; avoid stale results from URLSession/URLCache.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Notifications (REST only - not available via GraphQL)

    /// Fetches all notifications for the authenticated user.
    ///
    /// - Returns: An array of GitHub notifications
    /// - Throws: `APIError` if the request fails or response cannot be decoded
    public func fetchNotifications() async throws -> [GitHubNotification] {
        let endpoint = "\(baseURL)/notifications"
        let data = try await makeRequest(endpoint: endpoint)

        return try jsonDecoder.decode([GitHubNotification].self, from: data)
    }

    /// Marks a specific notification thread as read.
    ///
    /// - Parameter threadId: The unique identifier of the notification thread
    /// - Throws: `APIError` if the request fails
    public func markNotificationAsRead(threadId: String) async throws {
        let endpoint = "\(baseURL)/notifications/threads/\(threadId)"
        _ = try await makeRequest(endpoint: endpoint, method: "PATCH")
    }

    /// Marks all notifications as read for the authenticated user.
    ///
    /// - Throws: `APIError` if the request fails
    public func markAllNotificationsAsRead() async throws {
        let endpoint = "\(baseURL)/notifications"
        _ = try await makeRequest(endpoint: endpoint, method: "PUT")
    }

    // MARK: - Private

    private func makeRequest(endpoint: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.addValue("GitHubNotifier", forHTTPHeaderField: "User-Agent")
        request.addValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.addValue("no-cache", forHTTPHeaderField: "Pragma")

        if let body {
            request.httpBody = body
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)

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
            if let remaining = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
               remaining == "0" {
                throw APIError.rateLimited(resetTime: nil)
            }
        }

        // Handle unauthorized
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return data
    }
}

/// Errors that can occur during GitHub API interactions.
public enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case unauthorized
    case rateLimited(resetTime: Date?)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case let .httpError(statusCode):
            return "HTTP error: \(statusCode)"
        case let .decodingError(error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized. Please check your GitHub token."
        case let .rateLimited(resetTime):
            if let resetTime {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                let relativeTime = formatter.localizedString(for: resetTime, relativeTo: Date())
                return "Rate limit exceeded. Resets \(relativeTime)."
            }
            return "Rate limit exceeded. Please try again later."
        }
    }
}
