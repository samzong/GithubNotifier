import Foundation

// MARK: - Rule Engine

/// Engine for evaluating notifications against rules
public struct RuleEngine: Sendable {
    // Cache for compiled regex patterns to avoid recompilation overhead
    private static nonisolated(unsafe) var regexCache: [String: NSRegularExpression] = [:]
    private static let cacheLock = NSLock()

    public init() {}

    /// Prepare rules for evaluation (filter enabled and sort by priority)
    /// This should be called once before iterating over notifications
    public func prepareRules(_ rules: [NotificationRule]) -> [NotificationRule] {
        rules
            .filter(\.isEnabled)
            .sorted { $0.priority < $1.priority }
    }

    /// Evaluate a notification against a list of PREPARED rules
    /// Uses first-match strategy: returns result from first matching rule
    public func evaluate(
        notification: GitHubNotification,
        preparedRules: [NotificationRule]
    ) -> RuleResult {
        for rule in preparedRules where matches(notification: notification, rule: rule) {
            return buildResult(from: rule)
        }
        return .noMatch
    }

    /// Evaluate a notification against a list of raw rules
    /// Uses first-match strategy: returns result from first matching rule
    /// Note: Prefer using prepareRules() and the overload if evaluating against multiple notifications
    public func evaluate(
        notification: GitHubNotification,
        rules: [NotificationRule]
    ) -> RuleResult {
        let prepared = prepareRules(rules)
        return evaluate(notification: notification, preparedRules: prepared)
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
        let pattern = pattern.lowercased()
        let value = value.lowercased()

        // Simple case: exact match or universal wildcard
        if pattern == "*" {
            return true
        }

        if !pattern.contains("*") {
            return pattern == value
        }

        // Use cached regex if available
        let regex: NSRegularExpression? = Self.cacheLock.withLock {
            if let cached = Self.regexCache[pattern] {
                return cached
            }

            // Convert wildcard pattern to regex
            let regexPattern = "^" + NSRegularExpression.escapedPattern(for: pattern)
                .replacingOccurrences(of: "\\*", with: ".*") + "$"

            guard let newRegex = try? NSRegularExpression(pattern: regexPattern, options: []) else {
                return nil
            }

            Self.regexCache[pattern] = newRegex
            return newRegex
        }

        guard let regex else { return false }

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
