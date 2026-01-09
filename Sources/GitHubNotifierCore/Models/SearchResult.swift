import Foundation

/// Unified search result item for PR or Issue
/// Used by ActivityService to display user-related items
public struct SearchResultItem: Identifiable, Sendable, Hashable {
    public let id: String
    public let number: Int
    public let title: String
    public let state: String
    public let repositoryOwner: String
    public let repositoryName: String
    public let authorLogin: String?
    public let authorAvatarUrl: String?
    public let updatedAt: Date
    public let itemType: ItemType

    public enum ItemType: String, Sendable, Hashable {
        case pullRequest
        case issue
    }

    public var repositoryFullName: String {
        "\(repositoryOwner)/\(repositoryName)"
    }

    public var webURL: URL? {
        let resource = itemType == .pullRequest ? "pull" : "issues"
        return URL(string: "https://github.com/\(repositoryOwner)/\(repositoryName)/\(resource)/\(number)")
    }

    public let ciStatus: CIStatus?

    public init(
        id: String,
        number: Int,
        title: String,
        state: String,
        repositoryOwner: String,
        repositoryName: String,
        authorLogin: String?,
        authorAvatarUrl: String?,
        updatedAt: Date,
        itemType: ItemType,
        ciStatus: CIStatus? = nil
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.state = state
        self.repositoryOwner = repositoryOwner
        self.repositoryName = repositoryName
        self.authorLogin = authorLogin
        self.authorAvatarUrl = authorAvatarUrl
        self.updatedAt = updatedAt
        self.itemType = itemType
        self.ciStatus = ciStatus
    }
}
