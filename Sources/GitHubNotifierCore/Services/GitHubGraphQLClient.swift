import Foundation

/// Pure GraphQL client for GitHub API
/// For notifications management, use GitHubAPI (REST)
public actor GitHubGraphQLClient {
    private let graphqlEndpoint: URL
    private let token: String
    private let session: URLSession

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public init(
        token: String,
        graphqlEndpoint: URL = URL(string: "https://api.github.com/graphql")!
    ) {
        self.token = token
        self.graphqlEndpoint = graphqlEndpoint

        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - User Info

    public struct ViewerInfo: Decodable, Sendable {
        public let login: String
        public let avatarUrl: String
    }

    public func fetchViewer() async throws -> ViewerInfo {
        let query = """
        query {
          viewer {
            login
            avatarUrl
          }
        }
        """

        let result: ViewerData = try await execute(query: query)
        return result.viewer
    }

    private struct ViewerData: Decodable {
        let viewer: ViewerInfo
    }

    // MARK: - Core Query Method

    /// Execute GraphQL query
    private func execute<T: Decodable>(query: String, variables: [String: Any] = [:]) async throws -> T {
        let body = GraphQLRequest(query: query, variables: variables)

        var request = URLRequest(url: graphqlEndpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GraphQLError.invalidResponse
        }

        guard http.statusCode == 200 else {
            if http.statusCode == 401 {
                throw GraphQLError.unauthorized
            }
            throw GraphQLError.httpError(statusCode: http.statusCode)
        }

        let result = try decoder.decode(GraphQLResponse<T>.self, from: data)

        if let errors = result.errors, !errors.isEmpty {
            throw GraphQLError.graphQLErrors(errors.map(\.message))
        }

        guard let data = result.data else {
            throw GraphQLError.noData
        }

        return data
    }

    // MARK: - Notification Details

    /// Fetch notification details including reason and latest comment
    public func fetchNotificationDetails(
        owner: String,
        repo: String,
        number: Int,
        type: NotificationSubjectType
    ) async throws -> NotificationDetails {
        let query = switch type {
        case .pullRequest:
            """
            query($owner: String!, $repo: String!, $number: Int!) {
              repository(owner: $owner, name: $repo) {
                pullRequest(number: $number) {
                  title
                  state
                  author { login avatarUrl }
                  updatedAt
                  comments(last: 1) {
                    nodes {
                      author { login avatarUrl }
                      body
                      createdAt
                    }
                  }
                  commits(last: 1) {
                    nodes {
                      commit {
                        statusCheckRollup {
                          state
                          contexts(last: 100) {
                            nodes {
                              ... on CheckRun {
                                name
                                conclusion
                                status
                              }
                              ... on StatusContext {
                                context
                                state
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                  reviews(last: 5, states: [APPROVED, CHANGES_REQUESTED]) {
                    nodes {
                      author { login }
                      state
                    }
                  }
                }
              }
            }
            """
        case .issue:
            """
            query($owner: String!, $repo: String!, $number: Int!) {
              repository(owner: $owner, name: $repo) {
                issue(number: $number) {
                  title
                  state
                  author { login avatarUrl }
                  updatedAt
                  comments(last: 1) {
                    nodes {
                      author { login avatarUrl }
                      body
                      createdAt
                    }
                  }
                }
              }
            }
            """
        }

        let variables: [String: Any] = [
            "owner": owner,
            "repo": repo,
            "number": number,
        ]

        let result: NotificationDetailsData = try await execute(query: query, variables: variables)

        if type == .pullRequest {
            return result.repository.pullRequest!.toDetails()
        } else {
            return result.repository.issue!.toDetails()
        }
    }

    // MARK: - PR/Issue List Queries

    /// Fetch user's pull requests
    public func fetchMyPullRequests(first: Int = 20) async throws -> [PullRequestItem] {
        let query = """
        query($first: Int!) {
          viewer {
            pullRequests(first: $first, orderBy: {field: UPDATED_AT, direction: DESC}) {
              nodes {
                repository { nameWithOwner }
                number
                title
                state
                createdAt
                updatedAt
                author { login }
              }
            }
          }
        }
        """

        let result: MyPullRequestsData = try await execute(query: query, variables: ["first": first])
        return result.viewer.pullRequests.nodes
    }

    /// Fetch user's issues
    public func fetchMyIssues(first: Int = 20) async throws -> [IssueItem] {
        let query = """
        query($first: Int!) {
          viewer {
            issues(first: $first, orderBy: {field: UPDATED_AT, direction: DESC}) {
              nodes {
                repository { nameWithOwner }
                number
                title
                state
                createdAt
                updatedAt
                author { login }
              }
            }
          }
        }
        """

        let result: MyIssuesData = try await execute(query: query, variables: ["first": first])
        return result.viewer.issues.nodes
    }

    /// Fetch repository's pull requests
    public func fetchRepositoryPullRequests(
        owner: String,
        repo: String,
        states: [String] = ["OPEN"],
        first: Int = 20
    ) async throws -> [PullRequestItem] {
        let query = """
        query($owner: String!, $repo: String!, $states: [PullRequestState!], $first: Int!) {
          repository(owner: $owner, name: $repo) {
            pullRequests(states: $states, first: $first, orderBy: {field: UPDATED_AT, direction: DESC}) {
              nodes {
                repository { nameWithOwner }
                number
                title
                state
                createdAt
                updatedAt
                author { login }
              }
            }
          }
        }
        """

        let variables: [String: Any] = [
            "owner": owner,
            "repo": repo,
            "states": states,
            "first": first,
        ]

        let result: RepoPullRequestsData = try await execute(query: query, variables: variables)
        return result.repository.pullRequests.nodes
    }

    /// Fetch repository's issues
    public func fetchRepositoryIssues(
        owner: String,
        repo: String,
        states: [String] = ["OPEN"],
        first: Int = 20
    ) async throws -> [IssueItem] {
        let query = """
        query($owner: String!, $repo: String!, $states: [IssueState!], $first: Int!) {
          repository(owner: $owner, name: $repo) {
            issues(states: $states, first: $first, orderBy: {field: UPDATED_AT, direction: DESC}) {
              nodes {
                repository { nameWithOwner }
                number
                title
                state
                createdAt
                updatedAt
                author { login }
              }
            }
          }
        }
        """

        let variables: [String: Any] = [
            "owner": owner,
            "repo": repo,
            "states": states,
            "first": first,
        ]

        let result: RepoIssuesData = try await execute(query: query, variables: variables)
        return result.repository.issues.nodes
    }
}

// MARK: - Request/Response Types

private struct GraphQLRequest: Encodable {
    let query: String
    let variables: [String: Any]

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(query, forKey: .query)
        try container.encode(AnyCodable(variables), forKey: .variables)
    }

    private enum CodingKeys: String, CodingKey {
        case query, variables
    }
}

private struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLErrorDetail]?
}

private struct GraphQLErrorDetail: Decodable {
    let message: String
}

// MARK: - Response Models

public struct Viewer: Codable, Sendable {
    public let login: String
    public let name: String?
    public let avatarUrl: String
    public let email: String?
}

private struct ViewerData: Decodable {
    let viewer: Viewer
}

public struct NotificationDetails: Sendable {
    public let title: String
    public let state: String
    public let author: Author?
    public let updatedAt: Date
    public let latestComment: Comment?
    public let ciStatus: CIStatus?
    public let reviews: [Review]?
}

public struct Author: Codable, Sendable {
    public let login: String
    public let avatarUrl: String?
}

public struct Comment: Codable, Sendable {
    public let author: Author?
    public let body: String
    public let createdAt: Date
}

public struct CIStatus: Sendable, Hashable {
    public let state: String // SUCCESS, FAILURE, PENDING, ERROR
    public let checks: [CheckResult]
}

public struct CheckResult: Sendable, Hashable {
    public let name: String
    public let status: String // COMPLETED, IN_PROGRESS, QUEUED
    public let conclusion: String? // SUCCESS, FAILURE, NEUTRAL, CANCELLED, SKIPPED
}

public struct Review: Codable, Sendable {
    public let author: Author?
    public let state: String // APPROVED, CHANGES_REQUESTED
}

public struct PullRequestItem: Codable, Sendable {
    public let repository: Repository
    public let number: Int
    public let title: String
    public let state: String
    public let createdAt: Date
    public let updatedAt: Date
    public let author: Author?
}

public struct IssueItem: Codable, Sendable {
    public let repository: Repository
    public let number: Int
    public let title: String
    public let state: String
    public let createdAt: Date
    public let updatedAt: Date
    public let author: Author?
}

public struct Repository: Codable, Sendable {
    public let nameWithOwner: String
}

public enum NotificationSubjectType: Sendable {
    case pullRequest
    case issue
}

// MARK: - Internal Decodable Models

private struct NotificationDetailsData: Decodable {
    let repository: RepositoryDetails
}

private struct RepositoryDetails: Decodable {
    let pullRequest: PullRequestDetails?
    let issue: IssueDetails?
}

private struct PullRequestDetails: Decodable {
    let title: String
    let state: String
    let author: Author?
    let updatedAt: Date
    let comments: CommentConnection
    let commits: CommitConnection?
    let reviews: ReviewConnection?

    func toDetails() -> NotificationDetails {
        let latestComment = comments.nodes.first
        let ciStatus = commits?.nodes.first?.commit.statusCheckRollup?.toCIStatus()
        let reviewList = reviews?.nodes

        return NotificationDetails(
            title: title,
            state: state,
            author: author,
            updatedAt: updatedAt,
            latestComment: latestComment,
            ciStatus: ciStatus,
            reviews: reviewList
        )
    }
}

private struct IssueDetails: Decodable {
    let title: String
    let state: String
    let author: Author?
    let updatedAt: Date
    let comments: CommentConnection

    func toDetails() -> NotificationDetails {
        let latestComment = comments.nodes.first

        return NotificationDetails(
            title: title,
            state: state,
            author: author,
            updatedAt: updatedAt,
            latestComment: latestComment,
            ciStatus: nil,
            reviews: nil
        )
    }
}

private struct CommentConnection: Decodable {
    let nodes: [Comment]
}

private struct CommitConnection: Decodable {
    let nodes: [CommitNode]
}

private struct CommitNode: Decodable {
    let commit: CommitDetails
}

private struct CommitDetails: Decodable {
    let statusCheckRollup: StatusCheckRollup?
}

private struct StatusCheckRollup: Decodable {
    let state: String
    let contexts: ContextConnection

    func toCIStatus() -> CIStatus {
        let checks = contexts.nodes.compactMap { node -> CheckResult? in
            if let checkRun = node.checkRun {
                return CheckResult(
                    name: checkRun.name,
                    status: checkRun.status,
                    conclusion: checkRun.conclusion
                )
            } else if let statusContext = node.statusContext {
                return CheckResult(
                    name: statusContext.context,
                    status: "COMPLETED",
                    conclusion: statusContext.state
                )
            }
            return nil
        }

        return CIStatus(state: state, checks: checks)
    }
}

private struct ContextConnection: Decodable {
    let nodes: [ContextNode]
}

private struct ContextNode: Decodable {
    let checkRun: CheckRun?
    let statusContext: StatusContext?

    private enum CodingKeys: String, CodingKey {
        case checkRun, statusContext
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        checkRun = try? container.decode(CheckRun.self, forKey: .checkRun)
        statusContext = try? container.decode(StatusContext.self, forKey: .statusContext)
    }
}

private struct CheckRun: Decodable {
    let name: String
    let conclusion: String?
    let status: String
}

private struct StatusContext: Decodable {
    let context: String
    let state: String
}

private struct ReviewConnection: Decodable {
    let nodes: [Review]
}

private struct MyPullRequestsData: Decodable {
    let viewer: ViewerPullRequests
}

private struct ViewerPullRequests: Decodable {
    let pullRequests: PullRequestConnection
}

private struct PullRequestConnection: Decodable {
    let nodes: [PullRequestItem]
}

private struct MyIssuesData: Decodable {
    let viewer: ViewerIssues
}

private struct ViewerIssues: Decodable {
    let issues: IssueConnection
}

private struct IssueConnection: Decodable {
    let nodes: [IssueItem]
}

private struct RepoPullRequestsData: Decodable {
    let repository: RepoPullRequests
}

private struct RepoPullRequests: Decodable {
    let pullRequests: PullRequestConnection
}

private struct RepoIssuesData: Decodable {
    let repository: RepoIssues
}

private struct RepoIssues: Decodable {
    let issues: IssueConnection
}

// MARK: - Search API (I1 Infrastructure)

extension GitHubGraphQLClient {
    /// Search for Issues and Pull Requests using GitHub Search API
    /// - Parameters:
    ///   - query: GitHub search syntax (e.g., "is:open author:@me")
    ///   - first: Number of results to return
    /// - Returns: Array of SearchResultItem
    public func search(query: String, first: Int = 50) async throws -> [SearchResultItem] {
        let graphqlQuery = """
        query($query: String!, $first: Int!) {
          search(query: $query, type: ISSUE, first: $first) {
            nodes {
              __typename
              ... on PullRequest {
                id
                number
                title
                state
                repository {
                  owner { login }
                  name
                }
                author { login avatarUrl }
                updatedAt
                commits(last: 1) {
                  nodes {
                    commit {
                      statusCheckRollup {
                        state
                        contexts(last: 100) {
                          nodes {
                            ... on CheckRun {
                              name
                              conclusion
                              status
                            }
                            ... on StatusContext {
                              context
                              state
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
              ... on Issue {
                id
                number
                title
                state
                repository {
                  owner { login }
                  name
                }
                author { login avatarUrl }
                updatedAt
              }
            }
          }
        }
        """

        let variables: [String: Any] = [
            "query": query,
            "first": first,
        ]

        let result: SearchData = try await execute(query: graphqlQuery, variables: variables)
        return result.search.nodes.compactMap { node -> SearchResultItem? in
            guard let id = node.id,
                  let number = node.number,
                  let title = node.title,
                  let state = node.state,
                  let repositoryOwner = node.repository?.owner.login,
                  let repositoryName = node.repository?.name,
                  let updatedAt = node.updatedAt else {
                return nil
            }

            let itemType: SearchResultItem.ItemType = node.typename == "PullRequest" ? .pullRequest : .issue

            return SearchResultItem(
                id: id,
                number: number,
                title: title,
                state: state,
                repositoryOwner: repositoryOwner,
                repositoryName: repositoryName,
                authorLogin: node.author?.login,
                authorAvatarUrl: node.author?.avatarUrl,
                updatedAt: updatedAt,
                itemType: itemType,
                ciStatus: node.commits?.nodes.first?.commit.statusCheckRollup?.toCIStatus()
            )
        }
    }
}

private struct SearchData: Decodable {
    let search: SearchConnection
}

private struct SearchConnection: Decodable {
    let nodes: [SearchNode]
}

private struct SearchNode: Decodable {
    let typename: String?
    let id: String?
    let number: Int?
    let title: String?
    let state: String?
    let repository: SearchRepository?
    let author: Author?
    let updatedAt: Date?
    let commits: CommitConnection?

    private enum CodingKeys: String, CodingKey {
        case typename = "__typename"
        case id, number, title, state, repository, author, updatedAt, commits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        typename = try container.decodeIfPresent(String.self, forKey: .typename)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        number = try container.decodeIfPresent(Int.self, forKey: .number)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        repository = try container.decodeIfPresent(SearchRepository.self, forKey: .repository)
        author = try container.decodeIfPresent(Author.self, forKey: .author)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        commits = try container.decodeIfPresent(CommitConnection.self, forKey: .commits)
    }
}

private struct SearchRepository: Decodable {
    let owner: RepositoryOwner
    let name: String
}

private struct RepositoryOwner: Decodable {
    let login: String
}

// MARK: - Error Types

public enum GraphQLError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int)
    case graphQLErrors([String])
    case noData

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid GraphQL response"
        case .unauthorized:
            "Unauthorized: Invalid or expired token"
        case let .httpError(statusCode):
            "HTTP error: \(statusCode)"
        case let .graphQLErrors(errors):
            "GraphQL errors: \(errors.joined(separator: ", "))"
        case .noData:
            "No data returned from GraphQL"
        }
    }
}

// MARK: - Helper: AnyCodable for encoding arbitrary JSON

private struct AnyCodable: Encodable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Invalid JSON value"
                )
            )
        }
    }
}
