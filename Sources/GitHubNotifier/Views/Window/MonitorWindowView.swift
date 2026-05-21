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
            $0.target.displayName.localizedStandardContains(text) ||
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
            Text("monitor.management.delete.message".localized)
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
                            Text(monitor.target.displayName)
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

    private var isAddFormValid: Bool {
        if newMonitorType == .search, selectedSavedSearchId != nil {
            return true
        }
        return !newMonitorInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func resetAddForm() {
        newMonitorInput = ""
        newMonitorName = ""
        selectedSavedSearchId = nil
        addMonitorError = nil
        isValidatingNewMonitor = false
    }

    private func parseTarget(input: String, type: MonitorType) -> MonitorTarget? {
        MonitorTarget.parse(input: input, type: type.rawValue, name: newMonitorName)
    }

    @MainActor
    private func saveNewMonitor() async {
        guard let target = parseTarget(input: newMonitorInput, type: newMonitorType) else {
            addMonitorError = "monitor.management.error.invalid_target".localized
            return
        }

        isValidatingNewMonitor = true
        defer { isValidatingNewMonitor = false }

        guard await validateTarget(target) else {
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
    private func validateTarget(_ target: MonitorTarget) async -> Bool {
        switch target {
        case let .account(login):
            guard let restClient = session.restClient else {
                addMonitorError = "monitor.management.error.not_authenticated".localized
                return false
            }
            if await restClient.userExists(username: login) {
                addMonitorError = nil
                return true
            }
            addMonitorError = String(format: "monitor.management.error.account_not_found".localized, login)
            return false

        case let .repository(owner, name):
            guard let restClient = session.restClient else {
                addMonitorError = "monitor.management.error.not_authenticated".localized
                return false
            }
            if await restClient.repositoryExists(owner: owner, repo: name) {
                addMonitorError = nil
                return true
            }
            addMonitorError = String(format: "monitor.management.error.repo_not_found".localized, "\(owner)/\(name)")
            return false

        case .search, .code:
            addMonitorError = nil
            return true
        }
    }

    private var detailView: some View {
        Group {
            if let monitor = currentMonitor {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerCard(for: monitor)
                        filterCard(for: monitor)
                        eventsCard(for: monitor)
                    }
                    .padding()
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task {
                                await engine.sync(monitor: monitor)
                            }
                        } label: {
                            Label("monitor.management.sync_now".localized, systemImage: "arrow.triangle.2.circlepath")
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("common.delete".localized, systemImage: "trash")
                        }
                    }
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
    private func headerCard(for monitor: MonitorDefinition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconForTarget(monitor.target))
                    .font(.title)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(monitor.target.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(typeLabelForTarget(monitor.target))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
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
                    Text("monitor.management.cursor.label".localized)
                        .foregroundStyle(.secondary)
                    if let cursor = store.cursors[monitor.id] {
                        Text(cursor.prefix(30) + (cursor.count > 30 ? "..." : ""))
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Text("monitor.management.cursor.never_synced".localized)
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

    private func eventsCard(for monitor: MonitorDefinition) -> some View {
        let events = store.events.filter { $0.targetId == monitor.id }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("monitor.management.events.title".localized)
                    .font(.headline)
                Spacer()
                Text(String(format: "monitor.management.events.count".localized, events.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("monitor.management.events.empty".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 0) {
                    ForEach(events) { event in
                        eventRow(for: event)
                        if event.id != events.last?.id {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
            }
        }
        .padding()
        .liquidGlassSurface()
    }

    @ViewBuilder
    private func eventRow(for event: MonitorEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconForEventKind(event.kind))
                .font(.system(size: 16))
                .foregroundStyle(colorForEventKind(event.kind))
                .frame(width: 28, height: 28)
                .background(colorForEventKind(event.kind).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if !event.actor.isEmpty {
                        Text("@\(event.actor)")
                            .fontWeight(.semibold)
                    }
                    Text(event.repo)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(event.occurredAt.timeAgo())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                Text(event.title)
                    .font(.body)
                    .foregroundStyle(event.isRead ? .secondary : .primary)
                    .fontWeight(event.isRead ? .regular : .medium)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            store.markEventRead(id: event.id)
            if let url = URL(string: event.url) {
                NSWorkspace.shared.open(url)
            }
        }
    }

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

    private func iconForEventKind(_ kind: String) -> String {
        switch kind {
        case "commit": "arrow.triangle.pull"
        case "issue": "exclamationmark.bubble"
        case "pr": "arrow.triangle.merge"
        case "release": "shippingbox"
        case "comment": "text.bubble"
        case "code_match": "doc.text.magnifyingglass"
        default: "bell"
        }
    }

    private func colorForEventKind(_ kind: String) -> Color {
        switch kind {
        case "commit": .blue
        case "issue": .green
        case "pr": .purple
        case "release": .orange
        case "comment": .teal
        case "code_match": .cyan
        default: .secondary
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
