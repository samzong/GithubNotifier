//
//  RepositorySearchItem.swift
//  GitHubNotifierCore
//
//

import Foundation

public struct RepositorySearchItem: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let owner: String
    public let description: String?
    public let stargazerCount: Int
    public let language: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let isPrivate: Bool
    public let isFork: Bool

    public var fullName: String { "\(owner)/\(name)" }

    public var webURL: URL? {
        URL(string: "https://github.com/\(owner)/\(name)")
    }

    public init(
        id: String,
        name: String,
        owner: String,
        description: String?,
        stargazerCount: Int,
        language: String?,
        createdAt: Date,
        updatedAt: Date,
        isPrivate: Bool,
        isFork: Bool
    ) {
        self.id = id
        self.name = name
        self.owner = owner
        self.description = description
        self.stargazerCount = stargazerCount
        self.language = language
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPrivate = isPrivate
        self.isFork = isFork
    }
}
