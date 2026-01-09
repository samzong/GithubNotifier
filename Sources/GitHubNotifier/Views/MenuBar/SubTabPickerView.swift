import GitHubNotifierCore
import SwiftUI

struct SubTabPickerView: View {
    @Binding var selectedSubTab: MenuBarSubTab

    let mainTab: MenuBarMainTab
    let issuesCount: Int
    let prsCount: Int
    let isMarkingAsRead: Bool

    let onMarkAsRead: () async -> Void

    var body: some View {
        HStack(spacing: 8) {
            segmentedControl

            Spacer()

            if mainTab == .notifications {
                markAsReadButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var segmentedControl: some View {
        HStack(spacing: 2) {
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
}
