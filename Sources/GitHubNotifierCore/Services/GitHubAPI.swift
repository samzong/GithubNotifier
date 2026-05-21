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
        request.addValue("Branchlight", forHTTPHeaderField: "User-Agent")
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

// MARK: - Monitor Events and Code Search Structures & Methods

public struct GitHubEvent: Codable, Sendable {
    public let id: String
    public let type: String
    public let actor: Actor
    public let repo: Repo
    public let createdAt: Date
    public let payload: Payload?

    public struct Actor: Codable, Sendable {
        public let login: String
    }

    public struct Repo: Codable, Sendable {
        public let name: String
    }

    public struct Payload: Codable, Sendable {
        public let action: String?
        public let issue: IssueOrPR?
        public let pullRequest: IssueOrPR?
        public let release: ReleaseInfo?
        public let commits: [CommitInfo]?
        public let comment: CommentInfo?
        public let head: String?

        enum CodingKeys: String, CodingKey {
            case action
            case issue
            case pullRequest = "pull_request"
            case release
            case commits
            case comment
            case head
        }
    }

    public struct IssueOrPR: Codable, Sendable {
        public let title: String
        public let htmlUrl: String

        enum CodingKeys: String, CodingKey {
            case title
            case htmlUrl = "html_url"
        }
    }

    public struct ReleaseInfo: Codable, Sendable {
        public let name: String?
        public let tagName: String
        public let htmlUrl: String

        enum CodingKeys: String, CodingKey {
            case name
            case tagName = "tag_name"
            case htmlUrl = "html_url"
        }
    }

    public struct CommitInfo: Codable, Sendable {
        public let sha: String
        public let message: String
    }

    public struct CommentInfo: Codable, Sendable {
        public let body: String?
        public let htmlUrl: String

        enum CodingKeys: String, CodingKey {
            case body
            case htmlUrl = "html_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, type, actor, repo, payload
        case createdAt = "created_at"
    }
}

extension GitHubEvent {
    public var monitorKind: String {
        switch type {
        case "PushEvent": "commit"
        case "IssuesEvent": "issue"
        case "PullRequestEvent": "pr"
        case "IssueCommentEvent", "PullRequestReviewCommentEvent", "CommitCommentEvent": "comment"
        case "ReleaseEvent": "release"
        default: "activity"
        }
    }

    public var monitorTitle: String {
        switch type {
        case "PushEvent":
            if let firstCommit = payload?.commits?.first {
                return "Pushed commit: \(firstCommit.message)"
            }
            return "Pushed commits to repository"
        case "IssuesEvent":
            let action = payload?.action ?? "opened"
            let issueTitle = payload?.issue?.title ?? ""
            return "\(action.capitalized) Issue: \(issueTitle)"
        case "PullRequestEvent":
            let action = payload?.action ?? "opened"
            let prTitle = payload?.pullRequest?.title ?? ""
            return "\(action.capitalized) PR: \(prTitle)"
        case "IssueCommentEvent":
            if let title = payload?.issue?.title, !title.isEmpty {
                return "Commented on: \(title)"
            }
            return "Commented on issue"
        case "PullRequestReviewCommentEvent":
            if let title = payload?.pullRequest?.title, !title.isEmpty {
                return "Commented on: \(title)"
            }
            return "Commented on pull request"
        case "CommitCommentEvent":
            return "Commented on commit"
        case "ReleaseEvent":
            let tagName = payload?.release?.tagName ?? ""
            return "Released version: \(tagName)"
        default:
            return "Triggered \(type) activity"
        }
    }

    public var monitorURL: String {
        if let url = payload?.comment?.htmlUrl { return url }
        if let url = payload?.issue?.htmlUrl { return url }
        if let url = payload?.pullRequest?.htmlUrl { return url }
        if let url = payload?.release?.htmlUrl { return url }
        if type == "PushEvent" {
            if let sha = payload?.commits?.first?.sha, !sha.isEmpty {
                return "https://github.com/\(repo.name)/commit/\(sha)"
            }
            if let head = payload?.head, !head.isEmpty {
                return "https://github.com/\(repo.name)/commit/\(head)"
            }
        }
        return "https://github.com/\(repo.name)"
    }
}

public struct GitHubCodeSearchResult: Codable, Sendable {
    public let items: [Item]

    public struct Item: Codable, Sendable {
        public let sha: String
        public let name: String
        public let path: String
        public let htmlUrl: String
        public let repository: Repository

        enum CodingKeys: String, CodingKey {
            case sha, name, path
            case htmlUrl = "html_url"
            case repository
        }
    }

    public struct Repository: Codable, Sendable {
        public let fullName: String

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
        }
    }
}

extension GitHubAPI {
    /// Fetch public events for a specific user.
    public func fetchUserEvents(username: String) async throws -> [GitHubEvent] {
        let endpoint = "\(baseURL)/users/\(username)/events"
        let data = try await makeRequest(endpoint: endpoint)
        return try jsonDecoder.decode([GitHubEvent].self, from: data)
    }

    /// Fetch events for a specific repository.
    public func fetchRepoEvents(owner: String, repo: String) async throws -> [GitHubEvent] {
        let endpoint = "\(baseURL)/repos/\(owner)/\(repo)/events"
        let data = try await makeRequest(endpoint: endpoint)
        return try jsonDecoder.decode([GitHubEvent].self, from: data)
    }

    /// Search code by query.
    public func searchCode(query: String) async throws -> GitHubCodeSearchResult {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw APIError.invalidURL
        }
        let endpoint = "\(baseURL)/search/code?q=\(encodedQuery)"
        let data = try await makeRequest(endpoint: endpoint)
        return try jsonDecoder.decode(GitHubCodeSearchResult.self, from: data)
    }

    public func userExists(username: String) async -> Bool {
        do {
            _ = try await makeRequest(endpoint: "\(baseURL)/users/\(username)")
            return true
        } catch {
            return false
        }
    }

    public func repositoryExists(owner: String, repo: String) async -> Bool {
        do {
            _ = try await makeRequest(endpoint: "\(baseURL)/repos/\(owner)/\(repo)")
            return true
        } catch {
            return false
        }
    }
}
