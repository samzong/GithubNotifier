//
//  MonitorWindowView.swift
//  GitHubNotifier
//
//  Created by X on 5/21/26.
//

import GitHubNotifierCore
import SwiftUI

struct MonitorWindowView: View {
    @Environment(GitHubSession.self) private var session
    @Environment(MonitorStore.self) private var store
    @Environment(MonitorEngine.self) private var engine
    @Environment(SearchService.self) private var searchService

    @State private var selectedMonitorId: UUID?
    @State private var sidebarSearchText = ""
    @State private var showDeleteConfirmation = false
    @State private var syncingMonitorIds: Set<UUID> = []
    @State private var isEditingMonitor = false
    @State private var editMonitorType: MonitorType = .account
    @State private var editMonitorInput = ""
    @State private var editMonitorName = ""
    @State private var editMonitorError: String?
    @State private var isValidatingEditedMonitor = false

    @State private var isShowingAddPopover = false
    @State private var newMonitorType: MonitorType = .account
    @State private var newMonitorInput = ""
    @State private var newMonitorName = ""
    @State private var selectedSavedSearchId: UUID?
    @State private var addMonitorError: String?
    @State private var isValidatingNewMonitor = false

    enum MonitorType: String, CaseIterable, Identifiable {
        case account
        case repository
        case search
        case code

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .account: "monitor.management.type.account".localized
            case .repository: "monitor.management.type.repo".localized
            case .search: "monitor.management.type.search".localized
            case .code: "monitor.management.type.code".localized
            }
        }

        var icon: String {
            switch self {
            case .account: "person.crop.circle"
            case .repository: "folder"
            case .search: "magnifyingglass"
            case .code: "chevron.left.forwardslash.chevron.right"
            }
        }
    }

    private var currentMonitor: MonitorDefinition? {
        guard let id = selectedMonitorId else { return nil }
        return store.monitors.first { $0.id == id }
    }

    private var filteredMonitors: [MonitorDefinition] {
        let text = sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return store.monitors }
        return store.monitors.filter {
            $0.displayName.localizedStandardContains(text) ||
                $0.target.idString.localizedStandardContains(text)
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 800, minHeight: 600)
        .liquidWindowBackground()
        .navigationTitle("monitor.management.title".localized)
        .confirmationDialog(
            "monitor.management.delete.title".localized,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("common.delete".localized, role: .destructive) {
                if let id = selectedMonitorId {
                    store.removeMonitor(id: id)
                    selectedMonitorId = nil
                }
            }
            Button("common.cancel".localized, role: .cancel) {}
        } message: {
            Text(String(
                format: "monitor.management.delete.message".localized,
                currentMonitor?.displayName ?? "monitor.management.delete.fallback".localized
            ))
        }
        .onChange(of: selectedMonitorId) { _, _ in
            cancelMonitorEditing()
        }
    }

    private var sidebarView: some View {
        List(selection: $selectedMonitorId) {
            ForEach(filteredMonitors) { monitor in
                NavigationLink(value: monitor.id) {
                    HStack(spacing: 8) {
                        Image(systemName: iconForTarget(monitor.target))
                            .foregroundStyle(.secondary)
                            .imageScale(.medium)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(monitor.displayName)
                                .font(.body)
                                .lineLimit(1)
                            Text(typeLabelForTarget(monitor.target))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { monitor.isEnabled },
                            set: { store.updateMonitor(id: monitor.id, isEnabled: $0) }
                        ))
                        .toggleStyle(.switch)
                        .scaleEffect(0.8)
                        .labelsHidden()
                    }
                    .padding(.vertical, 4)
                    .contextMenu {
                        Button("common.delete".localized, role: .destructive) {
                            selectedMonitorId = monitor.id
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
        }
        .searchable(
            text: $sidebarSearchText,
            placement: .sidebar,
            prompt: Text("monitor.management.filter.placeholder".localized)
        )
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    isShowingAddPopover = true
                } label: {
                    Label("monitor.management.add".localized, systemImage: "plus")
                        .fontWeight(.medium)
                }
                .liquidGlassButtonStyle()
                .sheet(isPresented: $isShowingAddPopover) {
                    addMonitorView
                        .frame(width: 540)
                        .padding(24)
                }
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
}

extension MonitorWindowView {
    private var addMonitorView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "waveform.path.ecg")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .liquidGlassSurface(cornerRadius: 12, interactive: true, tint: Color.accentColor.opacity(0.08))

                VStack(alignment: .leading, spacing: 2) {
                    Text("monitor.management.add.title".localized)
                        .font(.headline)

                    Text("monitor.management.add.subtitle".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                AddMonitorFieldLabel("monitor.management.add.type.label".localized)

                Picker("", selection: $newMonitorType) {
                    ForEach(MonitorType.allCases) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 10) {
                if newMonitorType == .search, !searchService.savedSearches.isEmpty {
                    AddMonitorFieldLabel("monitor.management.saved_search.label".localized)
                    Picker("monitor.management.saved_search.label".localized, selection: $selectedSavedSearchId) {
                        Text("monitor.management.saved_search.placeholder".localized).tag(nil as UUID?)
                        ForEach(searchService.savedSearches) { search in
                            Text(search.name).tag(search.id as UUID?)
                        }
                    }
                    .onChange(of: selectedSavedSearchId) { _, newValue in
                        if let selected = searchService.savedSearches.first(where: { $0.id == newValue }) {
                            newMonitorInput = selected.query
                            newMonitorName = selected.name
                        }
                    }
                } else {
                    AddMonitorFieldLabel("monitor.management.add.target.label".localized)
                    TextField(targetPlaceholder, text: $newMonitorInput)
                        .textFieldStyle(.roundedBorder)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                AddMonitorFieldLabel("monitor.management.add.name.label".localized)
                TextField("monitor.management.add.name.placeholder".localized, text: $newMonitorName)
                    .textFieldStyle(.roundedBorder)
            }

            if let addMonitorError {
                Text(addMonitorError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("common.cancel".localized) {
                    isShowingAddPopover = false
                    resetAddForm()
                }
                .buttonStyle(.borderless)

                Spacer()

                if isValidatingNewMonitor {
                    ProgressView()
                        .controlSize(.small)
                }

                Button("common.save".localized) {
                    Task {
                        await saveNewMonitor()
                    }
                }
                .liquidGlassButtonStyle(prominent: true)
                .disabled(!isAddFormValid || isValidatingNewMonitor)
            }
            .padding(.top, 4)
        }
    }

    private var targetPlaceholder: String {
        switch newMonitorType {
        case .account:
            "monitor.management.add.account.placeholder".localized
        case .repository:
            "monitor.management.add.repo.placeholder".localized
        case .search:
            "monitor.management.add.search.placeholder".localized
        case .code:
            "monitor.management.add.code.placeholder".localized
        }
    }

    private var editTargetPlaceholder: String {
        switch editMonitorType {
        case .account:
            "monitor.management.add.account.placeholder".localized
        case .repository:
            "monitor.management.add.repo.placeholder".localized
        case .search:
            "monitor.management.add.search.placeholder".localized
        case .code:
            "monitor.management.add.code.placeholder".localized
        }
    }

    private var isAddFormValid: Bool {
        if newMonitorType == .search, selectedSavedSearchId != nil {
            return true
        }
        return !newMonitorInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isEditFormValid: Bool {
        !editMonitorInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func resetAddForm() {
        newMonitorInput = ""
        newMonitorName = ""
        selectedSavedSearchId = nil
        addMonitorError = nil
        isValidatingNewMonitor = false
    }

    private func normalizedMonitorName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func parseTarget(input: String, type: MonitorType) -> MonitorTarget? {
        MonitorTarget.parse(input: input, type: type.rawValue, name: newMonitorName)
    }

    private func parseTarget(input: String, type: MonitorType, name: String) -> MonitorTarget? {
        MonitorTarget.parse(input: input, type: type.rawValue, name: name)
    }

    private func startEditing(_ monitor: MonitorDefinition) {
        isEditingMonitor = true
        editMonitorType = monitorType(for: monitor.target)
        editMonitorInput = inputValue(for: monitor.target)
        editMonitorName = monitor.name ?? embeddedName(for: monitor.target) ?? ""
        editMonitorError = nil
        isValidatingEditedMonitor = false
    }

    private func cancelMonitorEditing() {
        isEditingMonitor = false
        editMonitorInput = ""
        editMonitorName = ""
        editMonitorError = nil
        isValidatingEditedMonitor = false
    }

    private func monitorType(for target: MonitorTarget) -> MonitorType {
        switch target {
        case .account:
            .account
        case .repository:
            .repository
        case .search:
            .search
        case .code:
            .code
        }
    }

    private func inputValue(for target: MonitorTarget) -> String {
        switch target {
        case let .account(login):
            login
        case let .repository(owner, name):
            "\(owner)/\(name)"
        case let .search(query, _), let .code(query, _):
            query
        }
    }

    private func embeddedName(for target: MonitorTarget) -> String? {
        switch target {
        case let .search(_, name), let .code(_, name):
            name
        case .account, .repository:
            nil
        }
    }

    @MainActor
    private func saveNewMonitor() async {
        guard let target = parseTarget(input: newMonitorInput, type: newMonitorType) else {
            addMonitorError = "monitor.management.error.invalid_target".localized
            return
        }

        isValidatingNewMonitor = true
        defer { isValidatingNewMonitor = false }

        if let error = await targetValidationError(for: target) {
            addMonitorError = error
            return
        }

        let defaultToggles: [String: Bool] = [
            "commit": true,
            "issue": true,
            "pr": true,
            "release": true,
            "comment": true,
            "activity": true,
        ]

        let definition = MonitorDefinition(
            target: target,
            name: normalizedMonitorName(newMonitorName),
            isEnabled: true,
            eventToggles: defaultToggles
        )

        guard store.addMonitor(definition) else {
            addMonitorError = "monitor.management.error.duplicate".localized
            return
        }

        await engine.sync(monitor: definition)

        isShowingAddPopover = false
        resetAddForm()
    }

    @MainActor
    private func saveEditedMonitor() async {
        guard let monitor = currentMonitor else { return }
        guard let target = parseTarget(input: editMonitorInput, type: editMonitorType, name: editMonitorName) else {
            editMonitorError = "monitor.management.error.invalid_target".localized
            return
        }

        isValidatingEditedMonitor = true
        defer { isValidatingEditedMonitor = false }

        let targetChanged = monitor.target.idString != target.idString
        if targetChanged, let error = await targetValidationError(for: target) {
            editMonitorError = error
            return
        }

        guard store.updateMonitorDetails(id: monitor.id, target: target, name: normalizedMonitorName(editMonitorName)) else {
            editMonitorError = "monitor.management.error.duplicate".localized
            return
        }

        isEditingMonitor = false
        editMonitorError = nil

        if targetChanged, let updatedMonitor = store.monitors.first(where: { $0.id == monitor.id }) {
            await engine.sync(monitor: updatedMonitor)
        }
    }

    @MainActor
    private func syncMonitor(_ monitor: MonitorDefinition) async {
        guard !syncingMonitorIds.contains(monitor.id) else { return }

        syncingMonitorIds.insert(monitor.id)
        defer { syncingMonitorIds.remove(monitor.id) }

        await engine.sync(monitor: monitor)
    }

    @MainActor
    private func targetValidationError(for target: MonitorTarget) async -> String? {
        switch target {
        case let .account(login):
            guard let restClient = session.restClient else {
                return "monitor.management.error.not_authenticated".localized
            }
            if await restClient.userExists(username: login) {
                return nil
            }
            return String(format: "monitor.management.error.account_not_found".localized, login)

        case let .repository(owner, name):
            guard let restClient = session.restClient else {
                return "monitor.management.error.not_authenticated".localized
            }
            if await restClient.repositoryExists(owner: owner, repo: name) {
                return nil
            }
            return String(format: "monitor.management.error.repo_not_found".localized, "\(owner)/\(name)")

        case .search, .code:
            return nil
        }
    }

    private var detailView: some View {
        Group {
            if let monitor = currentMonitor {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if isEditingMonitor {
                            editMonitorCard(for: monitor)
                        } else {
                            headerCard(for: monitor)
                            filterCard(for: monitor)
                            dangerZone(for: monitor)
                        }
                    }
                    .padding()
                }
            } else {
                emptyStateView
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("monitor.management.empty".localized, systemImage: "waveform.path.ecg")
        } description: {
            Text("monitor.management.empty.subtitle".localized)
        } actions: {
            Button("monitor.management.add".localized) {
                isShowingAddPopover = true
            }
            .liquidGlassButtonStyle(prominent: true)
        }
    }

    @ViewBuilder
    private func editMonitorCard(for monitor: MonitorDefinition) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "pencil")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .liquidGlassSurface(cornerRadius: 10, interactive: true, tint: Color.accentColor.opacity(0.08))

                VStack(alignment: .leading, spacing: 2) {
                    Text("monitor.management.edit.title".localized)
                        .font(.headline)
                    Text("monitor.management.edit.subtitle".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                AddMonitorFieldLabel("monitor.management.add.type.label".localized)
                Picker("", selection: $editMonitorType) {
                    ForEach(MonitorType.allCases) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                AddMonitorFieldLabel("monitor.management.add.target.label".localized)
                TextField(editTargetPlaceholder, text: $editMonitorInput)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                AddMonitorFieldLabel("monitor.management.add.name.label".localized)
                TextField("monitor.management.add.name.placeholder".localized, text: $editMonitorName)
                    .textFieldStyle(.roundedBorder)
            }

            if monitor.target.idString != parseTarget(input: editMonitorInput, type: editMonitorType, name: editMonitorName)?.idString {
                Label("monitor.management.edit.target_change_note".localized, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let editMonitorError {
                Text(editMonitorError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("common.cancel".localized) {
                    cancelMonitorEditing()
                }
                .buttonStyle(.borderless)

                Spacer()

                if isValidatingEditedMonitor {
                    ProgressView()
                        .controlSize(.small)
                }

                Button("common.save".localized) {
                    Task {
                        await saveEditedMonitor()
                    }
                }
                .liquidGlassButtonStyle(prominent: true)
                .disabled(!isEditFormValid || isValidatingEditedMonitor)
            }
        }
        .padding()
        .liquidGlassSurface()
    }

    @ViewBuilder
    private func headerCard(for monitor: MonitorDefinition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconForTarget(monitor.target))
                    .font(.title)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(monitor.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(typeLabelForTarget(monitor.target))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                HStack(spacing: 8) {
                    if syncingMonitorIds.contains(monitor.id) {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button {
                        Task {
                            await syncMonitor(monitor)
                        }
                    } label: {
                        Label("monitor.management.sync_now".localized, systemImage: "arrow.triangle.2.circlepath")
                    }
                    .controlSize(.small)
                    .liquidGlassButtonStyle()
                    .disabled(syncingMonitorIds.contains(monitor.id))
                }

                Button {
                    startEditing(monitor)
                } label: {
                    Label("common.edit".localized, systemImage: "pencil")
                }
                .controlSize(.small)
                .liquidGlassButtonStyle()
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("monitor.management.target.label".localized)
                        .foregroundStyle(.secondary)
                    Text(monitor.target.idString)
                        .font(.system(.body, design: .monospaced))
                }

                GridRow {
                    Text("monitor.management.status.label".localized)
                        .foregroundStyle(.secondary)
                    Text(monitor.isEnabled ? "monitor.management.status.enabled".localized : "monitor.management.status.disabled".localized)
                        .foregroundStyle(monitor.isEnabled ? .green : .secondary)
                }

                GridRow {
                    Text("monitor.management.last_synced.label".localized)
                        .foregroundStyle(.secondary)
                    if let lastSyncedAt = store.lastSyncedAt[monitor.id] {
                        Text(lastSyncedAt.timeAgo())
                    } else {
                        Text("monitor.management.last_synced.never".localized)
                            .italic()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.subheadline)
        }
        .padding()
        .liquidGlassSurface()
    }

    @ViewBuilder
    private func filterCard(for monitor: MonitorDefinition) -> some View {
        switch monitor.target {
        case .account, .repository:
            VStack(alignment: .leading, spacing: 12) {
                Text("monitor.management.filters.title".localized)
                    .font(.headline)

                Text("monitor.management.filters.description".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                let kinds = [
                    ("commit", "monitor.event.kind.commits".localized),
                    ("issue", "monitor.event.kind.issues".localized),
                    ("pr", "monitor.event.kind.prs".localized),
                    ("release", "monitor.event.kind.releases".localized),
                    ("comment", "monitor.event.kind.comments".localized),
                    ("activity", "monitor.event.kind.activity".localized),
                ]

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(kinds, id: \.0) { kind, label in
                        Toggle(label, isOn: Binding(
                            get: { monitor.eventToggles[kind, default: true] },
                            set: { newValue in
                                var toggles = monitor.eventToggles
                                toggles[kind] = newValue
                                store.updateMonitorToggles(id: monitor.id, toggles: toggles)
                            }
                        ))
                        .toggleStyle(.checkbox)
                    }
                }
            }
            .padding()
            .liquidGlassSurface()
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func dangerZone(for monitor: MonitorDefinition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("monitor.management.danger.title".localized)
                .font(.headline)

            Text("monitor.management.danger.description".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                selectedMonitorId = monitor.id
                showDeleteConfirmation = true
            } label: {
                Label("monitor.management.delete.button".localized, systemImage: "trash")
            }
            .controlSize(.small)
            .liquidGlassButtonStyle()
        }
        .padding()
        .liquidGlassSurface(tint: Color.red.opacity(0.04))
    }
}

extension MonitorWindowView {
    private func iconForTarget(_ target: MonitorTarget) -> String {
        switch target {
        case .account: "person.crop.circle"
        case .repository: "folder"
        case .search: "magnifyingglass"
        case .code: "chevron.left.forwardslash.chevron.right"
        }
    }

    private func typeLabelForTarget(_ target: MonitorTarget) -> String {
        switch target {
        case .account: "monitor.management.type.account".localized
        case .repository: "monitor.management.type.repo".localized
        case .search: "monitor.management.type.search".localized
        case .code: "monitor.management.type.code".localized
        }
    }
}

private struct AddMonitorFieldLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
