import Foundation

public struct GitHubNotification: Codable, Identifiable, Sendable {
    public let id: String
    public let unread: Bool
    public let reason: String
    public let updatedAt: Date
    public let lastReadAt: Date?
    public let subject: Subject
    public let repository: Repository
    public let url: String

    public enum CodingKeys: String, CodingKey {
        case id, unread, reason, url
        case updatedAt = "updated_at"
        case lastReadAt = "last_read_at"
        case subject, repository
    }

    public struct Subject: Codable, Sendable {
        public let title: String
        public let url: String?
        public let latestCommentUrl: String?
        public let type: String

        enum CodingKeys: String, CodingKey {
            case title, url, type
            case latestCommentUrl = "latest_comment_url"
        }
    }

    public struct Repository: Codable, Sendable {
        public let id: Int
        public let name: String
        public let fullName: String
        public let htmlUrl: String
        public let owner: Owner

        enum CodingKeys: String, CodingKey {
            case id, name, owner
            case fullName = "full_name"
            case htmlUrl = "html_url"
        }

        public struct Owner: Codable, Sendable {
            public let login: String
        }
    }
}

extension GitHubNotification {
    public var notificationType: NotificationType {
        NotificationType.from(subject.type)
    }

    public var displayTitle: String {
        subject.title
    }

    public var displaySubtitle: String {
        "\(repository.fullName) · \(reason.capitalized)"
    }

    public var issueOrPRNumber: Int? {
        guard let urlString = subject.url else { return nil }
        let components = urlString.split(separator: "/")
        return components.last.flatMap { Int($0) }
    }
}
