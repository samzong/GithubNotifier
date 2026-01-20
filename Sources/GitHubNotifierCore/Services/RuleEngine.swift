import Foundation

// MARK: - Rule Engine

/// Engine for evaluating notifications against rules
public struct RuleEngine: Sendable {
    public init() {}

    /// Evaluate a notification against a list of rules
    /// Uses first-match strategy: returns result from first matching rule
    public func evaluate(
        notification: GitHubNotification,
        rules: [NotificationRule]
    ) -> RuleResult {
        let enabledRules = rules
            .filter(\.isEnabled)
            .sorted { $0.priority < $1.priority }

        for rule in enabledRules where matches(notification: notification, rule: rule) {
            return buildResult(from: rule)
        }

        return .noMatch
    }

    // MARK: - Private

    private func matches(
        notification: GitHubNotification,
        rule: NotificationRule
    ) -> Bool {
        switch rule.logicOperator {
        case .and:
            return rule.conditions.allSatisfy { condition in
                matchesCondition(notification: notification, condition: condition)
            }
        case .any:
            return rule.conditions.contains { condition in
                matchesCondition(notification: notification, condition: condition)
            }
        }
    }

    private func matchesCondition(
        notification: GitHubNotification,
        condition: RuleCondition
    ) -> Bool {
        let fieldValue = extractFieldValue(from: notification, field: condition.field)

        switch condition.operator {
        case .equals:
            return fieldValue.caseInsensitiveCompare(condition.value) == .orderedSame
        case .notEquals:
            return fieldValue.caseInsensitiveCompare(condition.value) != .orderedSame
        case .matches:
            return wildcardMatch(pattern: condition.value, value: fieldValue)
        }
    }

    private func extractFieldValue(
        from notification: GitHubNotification,
        field: RuleField
    ) -> String {
        switch field {
        case .repository:
            notification.repository.fullName
        case .organization:
            notification.repository.owner.login
        case .notificationType:
            notification.subject.type
        case .reason:
            notification.reason
        }
    }

    /// Wildcard pattern matching with * support
    /// Examples:
    /// - "kubernetes/*" matches "kubernetes/kubernetes", "kubernetes/minikube"
    /// - "*" matches anything
    /// - "owner/repo" matches exactly "owner/repo"
    private func wildcardMatch(pattern: String, value: String) -> Bool {
        // Simple case: universal wildcard
        if pattern == "*" {
            return true
        }

        if !pattern.contains("*") {
            return pattern.caseInsensitiveCompare(value) == .orderedSame
        }

        // Optimization: Handle common wildcard patterns without regex
        if pattern.hasPrefix("*") && pattern.hasSuffix("*") {
            let inner = pattern.dropFirst().dropLast()
            if !inner.contains("*") {
                return value.range(of: inner, options: .caseInsensitive) != nil
            }
        } else if pattern.hasSuffix("*") {
            let prefix = pattern.dropLast()
            if !prefix.contains("*") {
                return value.prefix(prefix.count).caseInsensitiveCompare(prefix) == .orderedSame
            }
        } else if pattern.hasPrefix("*") {
            let suffix = pattern.dropFirst()
            if !suffix.contains("*") {
                return value.suffix(suffix.count).caseInsensitiveCompare(suffix) == .orderedSame
            }
        }

        // Convert wildcard pattern to regex
        let regexPattern = "^" + NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*") + "$"

        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: [.caseInsensitive]) else {
            return false
        }

        let range = NSRange(value.startIndex..., in: value)
        return regex.firstMatch(in: value, options: [], range: range) != nil
    }

    private func buildResult(from rule: NotificationRule) -> RuleResult {
        var shouldMarkAsRead = false
        var shouldSuppressNotification = false

        for action in rule.actions {
            switch action.type {
            case .markAsRead:
                shouldMarkAsRead = true
            case .suppressSystemNotification:
                shouldSuppressNotification = true
            }
        }

        return RuleResult(
            matchedRule: rule,
            shouldMarkAsRead: shouldMarkAsRead,
            shouldSuppressNotification: shouldSuppressNotification
        )
    }
}
