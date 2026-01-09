import Foundation

// MARK: - Rule Storage

/// Service for persisting notification rules
@MainActor
@Observable
public class RuleStorage {
    private static let storageKey = "notificationRules"

    public private(set) var rules: [NotificationRule] = []

    public init() {
        loadRules()
    }

    // MARK: - CRUD Operations

    public func addRule(_ rule: NotificationRule) {
        rules.append(rule)
        saveRules()
    }

    public func updateRule(_ rule: NotificationRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index] = rule
        saveRules()
    }

    public func deleteRule(_ rule: NotificationRule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
    }

    public func deleteRule(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
        saveRules()
    }

    public func moveRule(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        updatePriorities()
        saveRules()
    }

    public func toggleRule(_ rule: NotificationRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index].isEnabled.toggle()
        saveRules()
    }

    // MARK: - Persistence

    private func loadRules() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else {
            return
        }

        do {
            rules = try JSONDecoder().decode([NotificationRule].self, from: data)
        } catch {
            print("Failed to decode rules: \(error)")
        }
    }

    private func saveRules() {
        do {
            let data = try JSONEncoder().encode(rules)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            print("Failed to encode rules: \(error)")
        }
    }

    private func updatePriorities() {
        for index in rules.indices {
            rules[index].priority = index
        }
    }
}
