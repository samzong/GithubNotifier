import Observation

@MainActor
@Observable
final class SettingsNavigationState {
    var pendingTab: SettingsTab?

    func open(tab: SettingsTab?) {
        pendingTab = tab
    }

    func consumePendingTab() -> SettingsTab? {
        let tab = pendingTab
        pendingTab = nil
        return tab
    }
}
