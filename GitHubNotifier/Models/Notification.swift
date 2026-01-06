import Foundation

struct GitHubNotification: Codable, Identifiable {
    let id: String
    let unread: Bool
    let reason: String
    let updatedAt: Date
    let lastReadAt: Date?
    let subject: Subject
    let repository: Repository
    let url: String

    enum CodingKeys: String, CodingKey {
        case id, unread, reason, url
        case updatedAt = "updated_at"
        case lastReadAt = "last_read_at"
        case subject, repository
    }

    struct Subject: Codable {
        let title: String
        let url: String?
        let latestCommentUrl: String?
        let type: String

        enum CodingKeys: String, CodingKey {
            case title, url, type
            case latestCommentUrl = "latest_comment_url"
        }
    }

    struct Repository: Codable {
        let id: Int
        let name: String
        let fullName: String
        let htmlUrl: String
        let owner: Owner

        enum CodingKeys: String, CodingKey {
            case id, name, owner
            case fullName = "full_name"
            case htmlUrl = "html_url"
        }

        struct Owner: Codable {
            let login: String
        }
    }
}

struct PullRequest: Codable {
    let number: Int
    let state: String
    let title: String
    let body: String?
    let draft: Bool
    let merged: Bool
    let mergedAt: Date?
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case number, state, title, body, draft, merged
        case mergedAt = "merged_at"
        case htmlUrl = "html_url"
    }
}

struct Issue: Codable {
    let number: Int
    let state: String
    let stateReason: String?
    let title: String
    let body: String?
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case number, state, title, body
        case stateReason = "state_reason"
        case htmlUrl = "html_url"
    }
}

extension GitHubNotification {
    var notificationType: NotificationType {
        NotificationType.from(subject.type)
    }

    var displayTitle: String {
        subject.title
    }

    var displaySubtitle: String {
        "\(repository.fullName) · \(reason.capitalized)"
    }

    var issueOrPRNumber: Int? {
        guard let urlString = subject.url else { return nil }
        let components = urlString.split(separator: "/")
        return components.last.flatMap { Int($0) }
    }
}
