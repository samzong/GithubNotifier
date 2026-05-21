import GitHubNotifierCore
import SwiftUI

struct FilterBarView: View {
    @Binding var selectedFilter: ActivityFilter
    let filterCounts: [ActivityFilter: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Picker("", selection: $selectedFilter) {
                ForEach(availableFilters, id: \.self) { filter in
                    Text(filterTitle(filter))
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.mini)
            .fixedSize()
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 4)
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

    private func filterTitle(_ filter: ActivityFilter) -> String {
        let count = filterCounts[filter] ?? 0

        if count > 0 {
            return "\(filter.displayName) (\(count))"
        }
        return filter.displayName
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
