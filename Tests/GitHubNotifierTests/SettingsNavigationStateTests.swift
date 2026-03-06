import XCTest
@testable import GitHubNotifier

final class SettingsNavigationStateTests: XCTestCase {
    func test_pendingTab_changesDisplayedTab_withoutOverwritingSavedTab() {
        var selection = SettingsTabSelection(savedTab: .general)

        selection.applyPendingTab(.account)

        XCTAssertEqual(selection.displayedTab, .account)
        XCTAssertEqual(selection.savedTab, .general)
    }

    @MainActor
    func test_consumePendingTab_returnsValueOnce() {
        let navigationState = SettingsNavigationState()

        navigationState.open(tab: .account)

        XCTAssertEqual(navigationState.consumePendingTab(), .account)
        XCTAssertNil(navigationState.consumePendingTab())
    }
}
