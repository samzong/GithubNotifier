import GitHubNotifierCore
import SwiftUI

struct RulesTab: View {
    let settingsWidth: CGFloat

    @Environment(RuleStorage.self) private var ruleStorage
    @State private var showingEditor = false
    @State private var editingRule: NotificationRule?

    var body: some View {
        Form {
            Section {
                if ruleStorage.rules.isEmpty {
                    emptyStateView
                } else {
                    ForEach(ruleStorage.rules) { rule in
                        RuleRowView(
                            rule: rule,
                            onToggle: { ruleStorage.toggleRule(rule) },
                            onEdit: {
                                editingRule = rule
                                showingEditor = true
                            },
                            onDelete: { ruleStorage.deleteRule(rule) }
                        )
                    }
                    .onMove { source, destination in
                        ruleStorage.moveRule(from: source, to: destination)
                    }
                }
            } header: {
                HStack {
                    Text("rules.title".localized)

                    Spacer()

                    Menu {
                        Button("Import Rules...") {
                            importRules()
                        }
                        Button("Export Rules...") {
                            exportRules()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.button)
                    .controlSize(.small)
                    .fixedSize()

                    Button {
                        editingRule = nil
                        showingEditor = true
                    } label: {
                        Label("rules.add".localized, systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: settingsWidth)
        .sheet(isPresented: $showingEditor) {
            RuleEditorView(
                ruleStorage: ruleStorage,
                editingRule: editingRule,
                onSave: { showingEditor = false }
            )
        }
    }

    private func importRules() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try Data(contentsOf: url)
                    let rules = try JSONDecoder().decode([NotificationRule].self, from: data)
                    // Simple merge: append rules that have different IDs
                    // Or for user experience, maybe just add all as "Copies"?
                    // Let's rely on ID check.
                    for rule in rules {
                        // If ID exists, update. If not, append.
                        if ruleStorage.rules.contains(where: { $0.id == rule.id }) {
                            ruleStorage.updateRule(rule)
                        } else {
                            ruleStorage.addRule(rule)
                        }
                    }
                } catch {
                    print("Failed to import rules: \(error)")
                    // Ideally show an alert here
                }
            }
        }
    }

    private func exportRules() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "github_notifier_rules.json"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try JSONEncoder().encode(ruleStorage.rules)
                    try data.write(to: url)
                } catch {
                    print("Failed to export rules: \(error)")
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("rules.empty.title".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("rules.empty.subtitle".localized)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Rule Row

struct RuleRowView: View {
    let rule: NotificationRule
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: .init(
                get: { rule.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 4) {
                Text(rule.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(rule.isEnabled ? .primary : .secondary)

                HStack(spacing: 6) {
                    ForEach(rule.actions) { action in
                        HStack(spacing: 3) {
                            Image(systemName: action.type.icon)
                            Text(action.type.shortName)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            Button {
                onEdit()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Rule Editor

struct RuleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let ruleStorage: RuleStorage
    let editingRule: NotificationRule?
    let onSave: () -> Void

    @State private var name = ""
    @State private var isEnabled = true
    @State private var conditions: [RuleCondition] = []
    @State private var logicOperator: RuleLogicOperator = .and
    @State private var actions: Set<RuleActionType> = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("common.cancel".localized) {
                    dismiss()
                }

                Spacer()

                Text(editingRule == nil ? "rules.editor.new".localized : "rules.editor.edit".localized)
                    .font(.headline)

                Spacer()

                Button("common.save".localized) {
                    saveRule()
                }
                .disabled(name.isEmpty || conditions.isEmpty || actions.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            Form {
                Section {
                    TextField("rules.editor.name".localized, text: $name)
                    Toggle("rules.editor.enabled".localized, isOn: $isEnabled)
                }

                Section("rules.editor.conditions".localized) {
                    ForEach($conditions) { $condition in
                        ConditionRow(condition: $condition)
                    }
                    .onDelete { offsets in
                        conditions.remove(atOffsets: offsets)
                    }

                    Button {
                        conditions.append(RuleCondition(
                            field: .reason,
                            operator: .equals,
                            value: ""
                        ))
                    } label: {
                        Label("rules.editor.add_condition".localized, systemImage: "plus")
                    }

                    if conditions.count > 1 {
                        Picker("rules.editor.logic".localized, selection: $logicOperator) {
                            Text("AND").tag(RuleLogicOperator.and)
                            Text("OR").tag(RuleLogicOperator.any)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("rules.editor.actions".localized) {
                    ForEach(RuleActionType.allCases, id: \.self) { actionType in
                        Toggle(isOn: Binding(
                            get: { actions.contains(actionType) },
                            set: { isOn in
                                if isOn {
                                    actions.insert(actionType)
                                } else {
                                    actions.remove(actionType)
                                }
                            }
                        )) {
                            Label(actionType.displayName, systemImage: actionType.icon)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 640, height: 540)
        .onAppear {
            if let rule = editingRule {
                name = rule.name
                isEnabled = rule.isEnabled
                conditions = rule.conditions
                logicOperator = rule.logicOperator
                actions = Set(rule.actions.map(\.type))
            }
        }
    }

    private func saveRule() {
        let ruleActions = actions.map { RuleAction(type: $0) }

        if let existingRule = editingRule {
            var updatedRule = existingRule
            updatedRule.name = name
            updatedRule.isEnabled = isEnabled
            updatedRule.conditions = conditions
            updatedRule.logicOperator = logicOperator
            updatedRule.actions = ruleActions
            ruleStorage.updateRule(updatedRule)
        } else {
            let newRule = NotificationRule(
                name: name,
                isEnabled: isEnabled,
                priority: ruleStorage.rules.count,
                conditions: conditions,
                logicOperator: logicOperator,
                actions: ruleActions
            )
            ruleStorage.addRule(newRule)
        }

        onSave()
        dismiss()
    }
}

// MARK: - Condition Row

struct ConditionRow: View {
    @Binding var condition: RuleCondition

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: $condition.field) {
                ForEach(RuleField.allCases, id: \.self) { field in
                    Text(field.displayName).tag(field)
                }
            }
            .frame(width: 100)

            Picker("", selection: $condition.operator) {
                ForEach(availableOperators, id: \.self) { ruleOperator in
                    Text(ruleOperator.displayName).tag(ruleOperator)
                }
            }
            .frame(width: 120)

            valueField
        }
    }

    private var availableOperators: [RuleOperator] {
        if condition.field.supportsWildcard {
            RuleOperator.allCases
        } else {
            [.equals, .notEquals]
        }
    }

    @ViewBuilder private var valueField: some View {
        switch condition.field {
        case .reason:
            Picker("", selection: $condition.value) {
                Text("—").tag("")
                ForEach(NotificationReason.allCases, id: \.rawValue) { reason in
                    Text(reason.displayName).tag(reason.rawValue)
                }
            }
        case .notificationType:
            Picker("", selection: $condition.value) {
                Text("—").tag("")
                ForEach(NotificationType.allCases, id: \.rawValue) { type in
                    Text(type.displayName).tag(type.rawValue)
                }
            }
        default:
            TextField("rules.editor.value".localized, text: $condition.value)
                .textFieldStyle(.roundedBorder)
        }
    }
}
