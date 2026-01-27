import Foundation

// MARK: - Rule Engine

/// Engine for evaluating notifications against rules
public struct RuleEngine: Sendable {
    public init() {}

    /// Prepares rules for evaluation by filtering enabled ones and sorting by priority
    public func prepareRules(_ rules: [NotificationRule]) -> [NotificationRule] {
        return rules
            .filter(\.isEnabled)
            .sorted { $0.priority < $1.priority }
    }

    /// Evaluate a notification against a list of rules
    /// Uses first-match strategy: returns result from first matching rule
    public func evaluate(
        notification: GitHubNotification,
        rules: [NotificationRule]
    ) -> RuleResult {
        let optimizedRules = prepareRules(rules)
        return evaluate(notification: notification, optimizedRules: optimizedRules)
    }

    /// Evaluate a notification against a list of already prepared (optimized) rules
    /// Uses first-match strategy: returns result from first matching rule
    public func evaluate(
        notification: GitHubNotification,
        optimizedRules: [NotificationRule]
    ) -> RuleResult {
        for rule in optimizedRules where matches(notification: notification, rule: rule) {
            return buildResult(from: rule)
        }

        return .noMatch
    }

    // MARK: - Private

    private func matches(
        notification: GitHubNotification,
        rule: NotificationRule
    ) -> Bool {
        let conditionResults = rule.conditions.map { condition in
            matchesCondition(notification: notification, condition: condition)
        }

        switch rule.logicOperator {
        case .and:
            return conditionResults.allSatisfy(\.self)
        case .any:
            return conditionResults.contains { $0 }
        }
    }

    private func matchesCondition(
        notification: GitHubNotification,
        condition: RuleCondition
    ) -> Bool {
        let fieldValue = extractFieldValue(from: notification, field: condition.field)

        switch condition.operator {
        case .equals:
            return fieldValue.lowercased() == condition.value.lowercased()
        case .notEquals:
            return fieldValue.lowercased() != condition.value.lowercased()
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
        let pattern = pattern.lowercased()
        let value = value.lowercased()

        // Simple case: exact match or universal wildcard
        if pattern == "*" {
            return true
        }

        if !pattern.contains("*") {
            return pattern == value
        }

        // Optimization: Handle common wildcard patterns without regex
        if pattern.first == "*" && pattern.last == "*" {
            let inner = pattern.dropFirst().dropLast()
            if !inner.contains("*") {
                return value.contains(inner)
            }
        } else if pattern.last == "*" {
            let prefix = pattern.dropLast()
            if !prefix.contains("*") {
                return value.hasPrefix(prefix)
            }
        } else if pattern.first == "*" {
            let suffix = pattern.dropFirst()
            if !suffix.contains("*") {
                return value.hasSuffix(suffix)
            }
        }

        // Convert wildcard pattern to regex
        let regexPattern = "^" + NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*") + "$"

        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: []) else {
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
