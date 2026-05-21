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

    let pinnedSearches: [SavedSearch]
    @Binding var selectedSearchId: UUID?

    let onMarkAsRead: () async -> Void
    let onRefresh: () async -> Void
    let onManage: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            switch mainTab {
            case .notifications, .activity:
                notificationActivitySegmentedControl
            case .search:
                searchSegmentedControl
            }

            Spacer(minLength: 8)

            actionButtons
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var notificationActivitySegmentedControl: some View {
        Picker("", selection: $selectedSubTab) {
            if mainTab == .notifications {
                Label(segmentTitle("menubar.tab.all".localized, count: allCount), systemImage: "tray")
                    .tag(MenuBarSubTab.all)
            }

            Label(segmentTitle("menubar.tab.prs".localized, count: prsCount), systemImage: "arrow.triangle.pull")
                .tag(MenuBarSubTab.prs)

            Label(segmentTitle("menubar.tab.issues".localized, count: issuesCount), systemImage: "exclamationmark.circle")
                .tag(MenuBarSubTab.issues)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.mini)
    }

    private var searchSegmentedControl: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Picker("", selection: $selectedSearchId) {
                Label("menubar.filter.all".localized, systemImage: "magnifyingglass")
                    .tag(UUID?.none)

                ForEach(pinnedSearches) { search in
                    Label(search.name, systemImage: search.type.icon)
                        .tag(Optional(search.id))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.mini)
            .fixedSize()
        }
    }

    private func segmentTitle(_ title: String, count: Int) -> String {
        "\(title) (\(count))"
    }

    private var actionButtons: some View {
        HStack(spacing: 4) {
            switch mainTab {
            case .notifications:
                markAsReadButton
                refreshButton

            case .activity:
                refreshButton

            case .search:
                if let onManage {
                    manageButton(action: onManage)
                }
                refreshButton
            }
        }
        .padding(2)
        .liquidGlassSurface(cornerRadius: 11, interactive: true)
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
        .frame(width: 28, height: 26)
        .contentShape(Rectangle())
        .liquidGlassIconButtonStyle()
        .controlSize(.small)
        .help("menubar.mark_all_read".localized)
        .disabled(isMarkingAsRead)
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
        .frame(width: 28, height: 26)
        .contentShape(Rectangle())
        .liquidGlassIconButtonStyle()
        .controlSize(.small)
        .help("menubar.refresh".localized)
        .disabled(isLoading)
    }

    private func manageButton(action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 28, height: 26)
        .contentShape(Rectangle())
        .liquidGlassIconButtonStyle()
        .controlSize(.small)
        .help("Manage saved searches")
    }
}
