import Combine
import GitHubNotifierCore
import Sparkle
import SwiftUI

/// A view that provides a "Check for Updates…" button for Sparkle
struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel

    init(updater: SPUUpdater) {
        viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("about.check.update".localized, action: viewModel.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}

/// ViewModel for CheckForUpdatesView
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    private let updater: SPUUpdater
    private var cancellables = Set<AnyCancellable>()

    init(updater: SPUUpdater) {
        self.updater = updater

        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] canCheck in
                self?.canCheckForUpdates = canCheck
            }
            .store(in: &cancellables)
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}
