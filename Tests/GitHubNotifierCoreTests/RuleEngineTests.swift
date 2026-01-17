import XCTest
@testable import GitHubNotifierCore

final class RuleEngineTests: XCTestCase {
    var engine: RuleEngine!

    override func setUp() {
        super.setUp()
        engine = RuleEngine()
    }

    func testWildcardMatch() {
        let notification = makeNotification(
            repoName: "kubernetes/kubernetes",
            owner: "kubernetes"
        )

        let condition = RuleCondition(
            field: .repository,
            operator: .matches,
            value: "kubernetes/*"
        )
        let rule = NotificationRule(
            name: "K8s Rule",
            conditions: [condition],
            actions: [.markAsRead]
        )

        let result = engine.evaluate(notification: notification, rules: [rule])
        XCTAssertTrue(result.shouldMarkAsRead)
    }

    func testWildcardExactMatch() {
        let notification = makeNotification(
            repoName: "owner/repo",
            owner: "owner"
        )

        let condition = RuleCondition(
            field: .repository,
            operator: .matches,
            value: "owner/repo"
        )
        let rule = NotificationRule(
            name: "Exact Rule",
            conditions: [condition],
            actions: [.markAsRead]
        )

        let result = engine.evaluate(notification: notification, rules: [rule])
        XCTAssertTrue(result.shouldMarkAsRead)
    }

    func testWildcardNoMatch() {
         let notification = makeNotification(
            repoName: "other/repo",
            owner: "other"
        )

        let condition = RuleCondition(
            field: .repository,
            operator: .matches,
            value: "kubernetes/*"
        )
        let rule = NotificationRule(
            name: "K8s Rule",
            conditions: [condition],
            actions: [.markAsRead]
        )

        let result = engine.evaluate(notification: notification, rules: [rule])
        XCTAssertFalse(result.shouldMarkAsRead)
    }

    func testPrioritySorting() {
        let notification = makeNotification(
            repoName: "owner/repo",
            owner: "owner"
        )

        let condition = RuleCondition(
            field: .repository,
            operator: .matches,
            value: "owner/repo"
        )

        // Priority 10: Suppress
        let rule1 = NotificationRule(
            name: "Low Priority",
            priority: 10,
            conditions: [condition],
            actions: [.suppressSystemNotification]
        )

        // Priority 0: Mark as Read (Should match first)
        let rule2 = NotificationRule(
            name: "High Priority",
            priority: 0,
            conditions: [condition],
            actions: [.markAsRead]
        )

        let result = engine.evaluate(notification: notification, rules: [rule1, rule2])
        XCTAssertTrue(result.shouldMarkAsRead)
        XCTAssertFalse(result.shouldSuppressNotification)
    }

    private func makeNotification(repoName: String, owner: String) -> GitHubNotification {
        let ownerObj = GitHubNotification.Repository.Owner(login: owner)
        let repo = GitHubNotification.Repository(
            id: 1,
            name: repoName.components(separatedBy: "/").last ?? "",
            fullName: repoName,
            htmlUrl: "https://github.com/\(repoName)",
            owner: ownerObj
        )
        let subject = GitHubNotification.Subject(
            title: "Test",
            url: nil,
            latestCommentUrl: nil,
            type: "Issue"
        )

        return GitHubNotification(
            id: UUID().uuidString,
            unread: true,
            reason: "subscribed",
            updatedAt: Date(),
            lastReadAt: nil,
            subject: subject,
            repository: repo,
            url: "https://api.github.com/..."
        )
    }
}
