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
        let optimizedRules = prepare(rules: rules)
        return evaluate(notification: notification, rules: optimizedRules)
    }

    /// Optimized evaluation using pre-processed rules
    public func evaluate(
        notification: GitHubNotification,
        rules: [OptimizedRule]
    ) -> RuleResult {
        for rule in rules where matches(notification: notification, rule: rule) {
            return buildResult(from: rule.originalRule)
        }
        return .noMatch
    }

    /// Pre-process rules for efficient evaluation
    /// Filters enabled rules, sorts by priority, and pre-compiles regex/lowercased values
    public func prepare(rules: [NotificationRule]) -> [OptimizedRule] {
        rules
            .filter(\.isEnabled)
            .sorted { $0.priority < $1.priority }
            .map { rule in
                let optimizedConditions = rule.conditions.map { condition in
                    OptimizedCondition(
                        condition: condition,
                        lowercasedValue: condition.value.lowercased(),
                        wildcardMatcher: makeWildcardMatcher(for: condition)
                    )
                }
                return OptimizedRule(originalRule: rule, optimizedConditions: optimizedConditions)
            }
    }

    // MARK: - Private

    private func makeWildcardMatcher(for condition: RuleCondition) -> WildcardMatcher? {
        guard condition.operator == .matches else { return nil }

        let pattern = condition.value.lowercased()

        if pattern == "*" {
            return .universal
        }

        if !pattern.contains("*") {
            return .exact(pattern)
        }

        if pattern.first == "*" && pattern.last == "*" {
            let inner = String(pattern.dropFirst().dropLast())
            if !inner.contains("*") {
                return .contains(inner)
            }
        } else if pattern.last == "*" {
            let prefix = String(pattern.dropLast())
            if !prefix.contains("*") {
                return .prefix(prefix)
            }
        } else if pattern.first == "*" {
            let suffix = String(pattern.dropFirst())
            if !suffix.contains("*") {
                return .suffix(suffix)
            }
        }

        // Complex regex
        let regexPattern = "^" + NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*") + "$"

        if let regex = try? NSRegularExpression(pattern: regexPattern, options: []) {
            return .regex(regex)
        }

        // Fallback to exact match if regex fails (shouldn't happen)
        return .exact(pattern)
    }

    private func matches(
        notification: GitHubNotification,
        rule: OptimizedRule
    ) -> Bool {
        let conditionResults = rule.optimizedConditions.map { condition in
            matchesCondition(notification: notification, condition: condition)
        }

        switch rule.originalRule.logicOperator {
        case .and:
            return conditionResults.allSatisfy(\.self)
        case .any:
            return conditionResults.contains { $0 }
        }
    }

    private func matchesCondition(
        notification: GitHubNotification,
        condition: OptimizedCondition
    ) -> Bool {
        let fieldValue = extractFieldValue(from: notification, field: condition.condition.field)

        switch condition.condition.operator {
        case .equals:
            return fieldValue.lowercased() == condition.lowercasedValue
        case .notEquals:
            return fieldValue.lowercased() != condition.lowercasedValue
        case .matches:
            guard let matcher = condition.wildcardMatcher else { return false }
            return matchWildcard(value: fieldValue, matcher: matcher)
        }
    }

    private func matchWildcard(value: String, matcher: WildcardMatcher) -> Bool {
        let value = value.lowercased()

        switch matcher {
        case .universal:
            return true
        case .exact(let pattern):
            return value == pattern
        case .contains(let pattern):
            return value.contains(pattern)
        case .prefix(let pattern):
            return value.hasPrefix(pattern)
        case .suffix(let pattern):
            return value.hasSuffix(pattern)
        case .regex(let regex):
            let range = NSRange(value.startIndex..., in: value)
            return regex.firstMatch(in: value, options: [], range: range) != nil
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

// MARK: - Optimized Structures

public struct OptimizedRule: Sendable {
    public let originalRule: NotificationRule
    public let optimizedConditions: [OptimizedCondition]

    public init(originalRule: NotificationRule, optimizedConditions: [OptimizedCondition]) {
        self.originalRule = originalRule
        self.optimizedConditions = optimizedConditions
    }
}

public struct OptimizedCondition: Sendable {
    public let condition: RuleCondition
    public let lowercasedValue: String
    public let wildcardMatcher: WildcardMatcher?

    public init(condition: RuleCondition, lowercasedValue: String, wildcardMatcher: WildcardMatcher?) {
        self.condition = condition
        self.lowercasedValue = lowercasedValue
        self.wildcardMatcher = wildcardMatcher
    }
}

public enum WildcardMatcher: Sendable {
    case universal
    case exact(String)
    case contains(String)
    case prefix(String)
    case suffix(String)
    case regex(NSRegularExpression)
}
