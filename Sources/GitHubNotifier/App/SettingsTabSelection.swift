struct SettingsTabSelection {
    private(set) var savedTab: SettingsTab
    private(set) var displayedTab: SettingsTab

    init(savedTab: SettingsTab) {
        self.savedTab = savedTab
        displayedTab = savedTab
    }

    mutating func restoreSavedTab(_ savedTab: SettingsTab) {
        self.savedTab = savedTab
        displayedTab = savedTab
    }

    mutating func applyPendingTab(_ pendingTab: SettingsTab?) {
        guard let pendingTab else { return }
        displayedTab = pendingTab
    }

    mutating func userSelectedTab(_ tab: SettingsTab) {
        savedTab = tab
        displayedTab = tab
    }
}
