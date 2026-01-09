import GitHubNotifierCore
import SwiftUI

struct FilterBarView: View {
    @Binding var selectedFilter: ActivityFilter
    let filterCounts: [ActivityFilter: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableFilters, id: \.self) { filter in
                    filterButton(filter)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 6)
    }

    private var availableFilters: [ActivityFilter] {
        let hasReview = filterCounts[.reviewRequested] != nil
        let hasAll = filterCounts[.all] != nil

        if hasAll {
            return [.all, .created, .assigned, .mentioned, .reviewRequested]
        } else if hasReview {
            return [.created, .reviewRequested, .assigned, .mentioned]
        } else {
            return [.created, .assigned, .mentioned]
        }
    }

    private func filterButton(_ filter: ActivityFilter) -> some View {
        let isSelected = selectedFilter == filter
        let count = filterCounts[filter] ?? 0

        return Button {
            selectedFilter = filter
        } label: {
            HStack(spacing: 4) {
                Text(filter.displayName)
                    .font(.system(size: 11, weight: .medium))

                if count > 0 {
                    Text("(\(count))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.15)
                    : Color(nsColor: .controlBackgroundColor)
            )
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

extension ActivityFilter {
    var displayName: String {
        switch self {
        case .all:
            "menubar.filter.all".localized
        case .assigned:
            "menubar.filter.assigned".localized
        case .created:
            "menubar.filter.created".localized
        case .mentioned:
            "menubar.filter.mentioned".localized
        case .reviewRequested:
            "menubar.filter.review_requested".localized
        }
    }
}
