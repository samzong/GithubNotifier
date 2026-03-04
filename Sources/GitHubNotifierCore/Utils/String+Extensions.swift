import Foundation

extension String {
    public var localized: String {
        NSLocalizedString(self, comment: "")
    }
}
