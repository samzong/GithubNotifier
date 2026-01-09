import Foundation

// MARK: - Rule Model

/// A notification filtering rule
public struct NotificationRule: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var isEnabled: Bool
    public var priority: Int
    public var conditions: [RuleCondition]
    public var logicOperator: RuleLogicOperator
    public var actions: [RuleAction]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        priority: Int = 0,
        conditions: [RuleCondition],
        logicOperator: RuleLogicOperator = .and,
        actions: [RuleAction],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.priority = priority
        self.conditions = conditions
        self.logicOperator = logicOperator
        self.actions = actions
        self.createdAt = createdAt
    }
}

// MARK: - Condition

/// A single condition within a rule
public struct RuleCondition: Codable, Identifiable, Sendable {
    public let id: UUID
    public var field: RuleField
    public var `operator`: RuleOperator
    public var value: String

    public init(
        id: UUID = UUID(),
        field: RuleField,
        operator: RuleOperator,
        value: String
    ) {
        self.id = id
        self.field = field
        self.operator = `operator`
        self.value = value
    }
}

/// Fields that can be used in rule conditions
public enum RuleField: String, Codable, CaseIterable, Sendable {
    case repository
    case organization
    case notificationType
    case reason

    public var displayName: String {
        switch self {
        case .repository:
            "Repository"
        case .organization:
            "Organization"
        case .notificationType:
            "Type"
        case .reason:
            "Reason"
        }
    }

    /// Whether this field supports wildcard matching
    public var supportsWildcard: Bool {
        switch self {
        case .repository, .organization:
            true
        case .notificationType, .reason:
            false
        }
    }
}

/// Operators for comparing values
public enum RuleOperator: String, Codable, CaseIterable, Sendable {
    case equals
    case notEquals
    case matches // Wildcard matching with *

    public var displayName: String {
        switch self {
        case .equals:
            "equals"
        case .notEquals:
            "does not equal"
        case .matches:
            "matches"
        }
    }
}

/// Logic operator for combining multiple conditions
public enum RuleLogicOperator: String, Codable, Sendable {
    case and
    case any

    public var displayName: String {
        switch self {
        case .and:
            "AND"
        case .any:
            "OR"
        }
    }
}

// MARK: - Action

/// An action to perform when a rule matches
public struct RuleAction: Codable, Identifiable, Sendable {
    public let id: UUID
    public var type: RuleActionType

    public init(
        id: UUID = UUID(),
        type: RuleActionType
    ) {
        self.id = id
        self.type = type
    }
}

/// Types of actions that can be performed
public enum RuleActionType: String, Codable, CaseIterable, Sendable {
    case markAsRead
    case suppressSystemNotification

    public var displayName: String {
        switch self {
        case .markAsRead:
            "Mark as Read"
        case .suppressSystemNotification:
            "Suppress System Notification"
        }
    }

    public var icon: String {
        switch self {
        case .markAsRead:
            "checkmark.circle"
        case .suppressSystemNotification:
            "bell.slash"
        }
    }

    public var shortName: String {
        switch self {
        case .markAsRead:
            "Read"
        case .suppressSystemNotification:
            "Mute"
        }
    }
}

// MARK: - Rule Result

/// The result of evaluating a notification against rules
public struct RuleResult: Sendable {
    public let matchedRule: NotificationRule?
    public let shouldMarkAsRead: Bool
    public let shouldSuppressNotification: Bool

    public init(
        matchedRule: NotificationRule? = nil,
        shouldMarkAsRead: Bool = false,
        shouldSuppressNotification: Bool = false
    ) {
        self.matchedRule = matchedRule
        self.shouldMarkAsRead = shouldMarkAsRead
        self.shouldSuppressNotification = shouldSuppressNotification
    }

    /// No rule matched - default behavior
    public static let noMatch = RuleResult()
}

// MARK: - Reason Values

/// Known notification reason values from GitHub API
public enum NotificationReason: String, CaseIterable, Sendable {
    case assign
    case author
    case comment
    case ciActivity = "ci_activity"
    case invitation
    case manual
    case mention
    case reviewRequested = "review_requested"
    case securityAlert = "security_alert"
    case stateChange = "state_change"
    case subscribed
    case teamMention = "team_mention"

    public var displayName: String {
        switch self {
        case .assign:
            "Assigned"
        case .author:
            "Author"
        case .comment:
            "Comment"
        case .ciActivity:
            "CI Activity"
        case .invitation:
            "Invitation"
        case .manual:
            "Manual"
        case .mention:
            "Mention"
        case .reviewRequested:
            "Review Requested"
        case .securityAlert:
            "Security Alert"
        case .stateChange:
            "State Change"
        case .subscribed:
            "Subscribed"
        case .teamMention:
            "Team Mention"
        }
    }
}
