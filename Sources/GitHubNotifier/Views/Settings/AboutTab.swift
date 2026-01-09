import Sparkle
import SwiftUI

struct AboutTab: View {
    let updater: SPUUpdater
    let settingsWidth: CGFloat
    
    @State private var latestVersion: String?
    @State private var latestReleaseURL: String?
    @State private var isCheckingUpdate = false
    @State private var updateCheckResult: UpdateCheckResult = .none
    
    private let repoOwner = "samzong"
    private let repoName = "GitHubNotifier"

    private enum UpdateCheckResult {
        case none
        case upToDate
        case newVersionAvailable
        case error(String)
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)

            Text("GitHubNotifier")
                .font(.title)
                .fontWeight(.bold)

            Spacer().frame(height: 10)

            linksSection

            Divider()
                .padding(.horizontal, 40)

            versionSection

            Spacer()
        }
        .frame(width: settingsWidth, height: 380)
    }

    private var linksSection: some View {
        VStack(spacing: 12) {
            Link(destination: URL(string: "https://github.com/\(repoOwner)/\(repoName)")!) {
                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(.blue)
                    Text("about.github.repo".localized)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(repoOwner)/\(repoName)")
                        .foregroundStyle(.blue)
                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Link(destination: URL(string: "https://github.com/\(repoOwner)/\(repoName)/issues/new")!) {
                HStack {
                    Image(systemName: "exclamationmark.bubble")
                        .foregroundStyle(.blue)
                    Text("about.report.issue".localized)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 40)
    }

    private var versionSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("about.version".localized)
                Text("\(appVersion) (\(buildNumber))")
                    .foregroundStyle(.secondary)

                Spacer()

                CheckForUpdatesView(updater: updater)
            }

            switch updateCheckResult {
            case .upToDate:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("about.up.to.date".localized)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .font(.callout)
            case .newVersionAvailable:
                if let latestVersion {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.yellow)
                        Text("about.new.version".localized)
                        Text("v\(latestVersion)")
                            .fontWeight(.medium)
                        Spacer()
                        if let url = latestReleaseURL, let releaseURL = URL(string: url) {
                            Link("about.download".localized, destination: releaseURL)
                                .foregroundStyle(.blue)
                        }
                    }
                    .font(.callout)
                    .foregroundStyle(.blue)
                }
            case let .error(message):
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(message)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .font(.callout)
            case .none:
                EmptyView()
            }
        }
        .padding(.horizontal, 40)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
}
