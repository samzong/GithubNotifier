import GitHubNotifierCore
import SwiftUI

struct SubTabPickerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedSubTab: MenuBarSubTab

    let mainTab: MenuBarMainTab
    let allCount: Int
    let issuesCount: Int
    let prsCount: Int
    let isMarkingAsRead: Bool
    let isLoading: Bool

    // Search tab: pinned searches and selection
    let pinnedSearches: [SavedSearch]
    @Binding var selectedSearchId: UUID?

    let onMarkAsRead: () async -> Void
    let onOpenRules: () -> Void
    let onRefresh: () async -> Void
    let onManage: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            switch mainTab {
            case .notifications, .activity:
                notificationActivitySegmentedControl
            case .search:
                searchSegmentedControl
            }

            Spacer()

            actionButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Notifications / Activity Segmented Control

    private var notificationActivitySegmentedControl: some View {
        HStack(spacing: 2) {
            if mainTab == .notifications {
                segmentButton("menubar.tab.all".localized, tab: .all, count: allCount, icon: "tray")
            }
            segmentButton("menubar.tab.prs".localized, tab: .prs, count: prsCount, icon: "arrow.triangle.pull")
            segmentButton("menubar.tab.issues".localized, tab: .issues, count: issuesCount, icon: "exclamationmark.circle")
        }
        .padding(2)
        .background(Color(nsColor: .separatorColor).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func segmentButton(_ title: String, tab: MenuBarSubTab, count: Int, icon: String) -> some View {
        let isSelected = selectedSubTab == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedSubTab = tab
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text("\(title) (\(count))")
                    .font(.caption)
                    .fontWeight(isSelected ? .medium : .regular)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isSelected
                    ? Color(nsColor: .controlBackgroundColor)
                    : Color.clear
            )
            .foregroundStyle(isSelected ? .primary : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: isSelected ? .black.opacity(0.12) : .clear, radius: 1, y: 0.5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Segmented Control (Pinned Searches)

    private var searchSegmentedControl: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                // "All" button
                searchSegmentButton(
                    title: "menubar.filter.all".localized,
                    icon: "magnifyingglass",
                    isSelected: selectedSearchId == nil,
                    action: { selectedSearchId = nil }
                )

                // Pinned searches
                ForEach(pinnedSearches) { search in
                    searchSegmentButton(
                        title: search.name,
                        icon: search.type.icon,
                        isSelected: selectedSearchId == search.id,
                        action: { selectedSearchId = search.id }
                    )
                }
            }
            .padding(2)
            .background(Color(nsColor: .separatorColor).opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func searchSegmentButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .medium : .regular)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isSelected
                    ? Color(nsColor: .controlBackgroundColor)
                    : Color.clear
            )
            .foregroundStyle(isSelected ? .primary : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: isSelected ? .black.opacity(0.12) : .clear, radius: 1, y: 0.5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action Buttons

    @ViewBuilder private var actionButtons: some View {
        switch mainTab {
        case .notifications:
            // Notifications: Mark as Read, Rules, Refresh
            markAsReadButton
            rulesButton
            refreshButton

        case .activity:
            // Activities: Refresh only
            refreshButton

        case .search:
            // Search: Manage, Refresh
            if let onManage {
                manageButton(action: onManage)
            }
            refreshButton
        }
    }

    private var markAsReadButton: some View {
        Button {
            Task { await onMarkAsRead() }
        } label: {
            if isMarkingAsRead {
                ProgressView()
                    .scaleEffect(0.6)
            } else {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .help("menubar.mark_all_read".localized)
        .disabled(isMarkingAsRead)
    }

    private var rulesButton: some View {
        Button {
            onOpenRules()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.purple)
        }
        .buttonStyle(.plain)
        .help("settings.tab.rules".localized)
    }

    private var refreshButton: some View {
        Button {
            Task { await onRefresh() }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isLoading && !reduceMotion ? 360 : 0))
                .animation(
                    isLoading && !reduceMotion
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                    value: isLoading
                )
        }
        .buttonStyle(.plain)
        .help("menubar.refresh".localized)
        .disabled(isLoading)
    }

    private func manageButton(action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.purple)
        }
        .buttonStyle(.plain)
        .help("Manage saved searches")
    }
}
