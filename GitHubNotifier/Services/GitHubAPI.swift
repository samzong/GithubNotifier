//
//  GitHubAPI.swift
//  GitHubNotifier
//
//  Service layer for GitHub API interactions.
//  Handles authentication, request formatting, and response parsing.
//

import Foundation

/// Service class for interacting with the GitHub REST API.
///
/// Provides methods for fetching notifications, marking them as read,
/// and retrieving detailed information about pull requests and issues.
/// Handles rate limiting, authentication errors, and network issues.
class GitHubAPI {
    private let baseURL = "https://api.github.com"
    private var token: String
    private let session: URLSession

    /// Configured JSON decoder for GitHub API responses.
    /// Uses ISO8601 date decoding strategy to match GitHub's date format.
    private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Initializes a new GitHub API client.
    ///
    /// - Parameter token: GitHub personal access token for authentication
    init(token: String) {
        self.token = token

        // GitHub notifications are time-sensitive; avoid stale results from URLSession/URLCache.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    /// Fetches all notifications for the authenticated user.
    ///
    /// - Returns: An array of GitHub notifications
    /// - Throws: `APIError` if the request fails or response cannot be decoded
    func fetchNotifications() async throws -> [GitHubNotification] {
        let endpoint = "\(baseURL)/notifications"
        let data = try await makeRequest(endpoint: endpoint)

        return try jsonDecoder.decode([GitHubNotification].self, from: data)
    }

    /// Marks a specific notification thread as read.
    ///
    /// - Parameter threadId: The unique identifier of the notification thread
    /// - Throws: `APIError` if the request fails
    func markNotificationAsRead(threadId: String) async throws {
        let endpoint = "\(baseURL)/notifications/threads/\(threadId)"
        _ = try await makeRequest(endpoint: endpoint, method: "PATCH")
    }

    /// Marks all notifications as read for the authenticated user.
    ///
    /// - Throws: `APIError` if the request fails
    func markAllNotificationsAsRead() async throws {
        let endpoint = "\(baseURL)/notifications"
        _ = try await makeRequest(endpoint: endpoint, method: "PUT")
    }

    /// Fetches detailed information about a specific pull request.
    ///
    /// - Parameters:
    ///   - owner: The repository owner's username
    ///   - repo: The repository name
    ///   - number: The pull request number
    /// - Returns: Detailed pull request information including state and metadata
    /// - Throws: `APIError` if the request fails or response cannot be decoded
    func fetchPullRequest(owner: String, repo: String, number: Int) async throws -> PullRequest {
        let endpoint = "\(baseURL)/repos/\(owner)/\(repo)/pulls/\(number)"
        let data = try await makeRequest(endpoint: endpoint)

        return try jsonDecoder.decode(PullRequest.self, from: data)
    }

    /// Fetches detailed information about a specific issue.
    ///
    /// - Parameters:
    ///   - owner: The repository owner's username
    ///   - repo: The repository name
    ///   - number: The issue number
    /// - Returns: Detailed issue information including state and metadata
    /// - Throws: `APIError` if the request fails or response cannot be decoded
    func fetchIssue(owner: String, repo: String, number: Int) async throws -> Issue {
        let endpoint = "\(baseURL)/repos/\(owner)/\(repo)/issues/\(number)"
        let data = try await makeRequest(endpoint: endpoint)

        return try jsonDecoder.decode(Issue.self, from: data)
    }

    /// Makes an HTTP request to the GitHub API.
    ///
    /// Handles authentication, rate limiting, and common error cases.
    ///
    /// - Parameters:
    ///   - endpoint: The full API endpoint URL
    ///   - method: HTTP method (GET, POST, PATCH, PUT, DELETE). Defaults to GET
    ///   - body: Optional request body data
    /// - Returns: The response data
    /// - Throws: `APIError` for various failure conditions
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

        if let body = body {
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

/// Errors that can occur during GitHub API interactions.
enum APIError: Error, LocalizedError {
    /// The provided endpoint URL is malformed
    case invalidURL

    /// The server response is not a valid HTTP response
    case invalidResponse

    /// The server returned an HTTP error status code
    case httpError(statusCode: Int)

    /// Failed to decode the JSON response
    case decodingError(Error)

    /// Authentication failed - invalid or expired token
    case unauthorized

    /// Rate limit exceeded - includes optional reset time
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
