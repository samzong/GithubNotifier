import Foundation

struct AppConfiguration {
    private enum Keys {
        static let githubOAuthClientID = "GitHubOAuthClientID"
    }

    let githubOAuthClientID: String

    init(infoDictionary: [String: Any]) {
        guard let clientID = infoDictionary[Keys.githubOAuthClientID] as? String,
              !clientID.isEmpty
        else {
            preconditionFailure("Missing \(Keys.githubOAuthClientID) in Info.plist")
        }

        githubOAuthClientID = clientID
    }

    static func load(from bundle: Bundle = .main) -> Self {
        Self(infoDictionary: bundle.infoDictionary ?? [:])
    }
}
