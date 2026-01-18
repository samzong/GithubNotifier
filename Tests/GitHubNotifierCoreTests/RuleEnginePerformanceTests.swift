import XCTest
@testable import GitHubNotifierCore

final class RuleEnginePerformanceTests: XCTestCase {
    var ruleEngine: RuleEngine!
    var rules: [NotificationRule]!
    var notifications: [GitHubNotification]!

    override func setUp() {
        super.setUp()
        ruleEngine = RuleEngine()

        // Generate rules with wildcards
        rules = (0..<50).map { i in
            NotificationRule(
                name: "Rule \(i)",
                conditions: [
                    RuleCondition(
                        field: .repository,
                        operator: .matches,
                        value: "org/repo-\(i)-*" // Prefix match
                    ),
                    RuleCondition(
                        field: .repository,
                        operator: .matches,
                        value: "*-\(i)-suffix" // Suffix match
                    )
                ],
                actions: []
            )
        }

        // Generate notifications
        notifications = (0..<1000).map { i in
            GitHubNotification(
                id: "\(i)",
                repository: .init(
                    id: i,
                    nodeId: "node-\(i)",
                    name: "repo-\(i)-something",
                    fullName: "org/repo-\(i)-something",
                    owner: .init(login: "org", avatarUrl: nil)
                ),
                subject: .init(title: "Title", url: "", latestCommentUrl: nil, type: "Issue"),
                reason: "subscribed",
                unread: true,
                updatedAt: Date(),
                lastReadAt: nil,
                url: ""
            )
        }
    }

    func testEvaluatePerformance() {
        measure {
            for notification in notifications {
                _ = ruleEngine.evaluate(notification: notification, rules: rules)
            }
        }
    }
}
