import GitHubNotifierCore
import SwiftUI

struct ActivityListView: View {
    @Environment(ActivityService.self) private var service

    let subTab: MenuBarSubTab
    let filter: ActivityFilter
    let onItemTap: (SearchResultItem) -> Void

    var body: some View {
        Group {
            if service.isLoading, service.items.isEmpty {
                loadingView
            } else if let error = service.errorMessage {
                errorView(error)
            } else if displayedItems.isEmpty {
                emptyView
            } else {
                listView
            }
        }
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(displayedItems) { item in
                    ActivityRowView(item: item) {
                        onItemTap(item)
                    }

                    if item.id != displayedItems.last?.id {
                        Divider()
                            .padding(.leading, 44)
                    }
                }

                if totalFilteredCount > displayedItems.count {
                    truncationFooter
                }
            }
        }
    }

    private var truncationFooter: some View {
        Button {
            if let url = viewAllURL {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 4) {
                Text("menubar.view_all_on_github".localized)
                    .font(.caption)
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
            }
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var viewAllURL: URL? {
        let baseURL = "https://github.com"
        let typeFilter = switch subTab {
        case .all:
            ""
        case .issues:
            "+type:issue"
        case .prs:
            "+type:pr"
        }

        let stateFilter = switch filter {
        case .all:
            "is:open"
        case .assigned:
            "is:open+assignee:@me"
        case .created:
            "is:open+author:@me"
        case .mentioned:
            "is:open+mentions:@me"
        case .reviewRequested:
            "is:open+review-requested:@me"
        }

        return URL(string: "\(baseURL)/issues?q=\(stateFilter)\(typeFilter)")
    }

    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.7)
            Text("menubar.loading".localized)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(error)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("menubar.no_items".localized)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var displayedItems: [SearchResultItem] {
        switch subTab {
        case .all:
            Array(filteredItems.prefix(20))
        case .issues:
            Array(filteredItems.filter { $0.itemType == .issue }.prefix(20))
        case .prs:
            Array(filteredItems.filter { $0.itemType == .pullRequest }.prefix(20))
        }
    }

    private var totalFilteredCount: Int {
        switch subTab {
        case .all:
            filteredItems.count
        case .issues:
            filteredItems.count(where: { $0.itemType == .issue })
        case .prs:
            filteredItems.count(where: { $0.itemType == .pullRequest })
        }
    }

    private var filteredItems: [SearchResultItem] {
        switch filter {
        case .all:
            service.items
        case .assigned:
            service.assignedItems
        case .created:
            service.createdItems
        case .mentioned:
            service.mentionedItems
        case .reviewRequested:
            service.reviewRequestedItems
        }
    }
}
