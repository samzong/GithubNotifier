//
//  GitHubSession.swift
//  GitHubNotifierCore
//
//  Created by X on 5/21/26.
//

import Foundation

/// Manages the authenticated session for GitHub APIs.
/// Provides unified access to REST and GraphQL clients.
@Observable
@MainActor
public final class GitHubSession {
    public private(set) var token: String?
    public private(set) var graphqlClient: GitHubGraphQLClient?
    public private(set) var restClient: GitHubAPI?

    public var isAuthenticated: Bool {
        token != nil
    }

    public init() {}

    /// Configures the session with a GitHub access token.
    ///
    /// - Parameter token: The personal access token or OAuth token.
    public func configure(token: String) {
        self.token = token
        self.graphqlClient = GitHubGraphQLClient(token: token)
        self.restClient = GitHubAPI(token: token)
    }

    /// Clears the active session and cancels references to API clients.
    public func clear() {
        self.token = nil
        self.graphqlClient = nil
        self.restClient = nil
    }
}
