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
            } else if filteredItems.isEmpty {
                emptyView
            } else {
                listView
            }
        }
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredItems) { item in
                    ActivityRowView(item: item) {
                        onItemTap(item)
                    }

                    if item.id != filteredItems.last?.id {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
        }
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

    private var filteredItems: [SearchResultItem] {
        let baseItems = legacyFilteredItems
        switch subTab {
        case .all:
            return Array(baseItems.prefix(20))
        case .issues:
            return Array(baseItems.filter { $0.itemType == .issue }.prefix(20))
        case .prs:
            return Array(baseItems.filter { $0.itemType == .pullRequest }.prefix(20))
        }
    }

    private var legacyFilteredItems: [SearchResultItem] {
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
