import Sparkle
import SwiftUI

struct AboutTab: View {
    let updater: SPUUpdater
    let settingsWidth: CGFloat

    private let repoOwner = "samzong"
    private let repoName = "GitHubNotifier"

    var body: some View {
        Form {
            Section {
                appIdentityRow
            }

            Section {
                repoLink
                issueLink
            }

            Section {
                versionSection
            }
        }
        .formStyle(.grouped)
        .frame(width: settingsWidth)
    }

    private var appIdentityRow: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("GitHubNotifier")
                    .font(.headline)
                Text("\(appVersion) (\(buildNumber))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var repoLink: some View {
        Link(destination: URL(string: "https://github.com/\(repoOwner)/\(repoName)")!) {
            HStack {
                Label("about.github.repo".localized, systemImage: "link")
                Spacer()
                Text("\(repoOwner)/\(repoName)")
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.up.forward")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var issueLink: some View {
        Link(destination: URL(string: "https://github.com/\(repoOwner)/\(repoName)/issues/new")!) {
            HStack {
                Label("about.report.issue".localized, systemImage: "exclamationmark.bubble")
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var versionSection: some View {
        HStack {
            Text("about.version".localized)
            Text("\(appVersion) (\(buildNumber))")
                .foregroundStyle(.secondary)

            Spacer()

            CheckForUpdatesView(updater: updater)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
}
