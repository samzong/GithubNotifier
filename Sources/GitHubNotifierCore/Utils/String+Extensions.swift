import Foundation

extension String {
    public var localized: String {
        NSLocalizedString(self, comment: "")
    }

    public func truncate(to length: Int, addEllipsis: Bool = true) -> String {
        if self.count <= length {
            return self
        }

        let endIndex = self.index(self.startIndex, offsetBy: length)
        let truncated = String(self[..<endIndex])
        return addEllipsis ? truncated + "..." : truncated
    }

    public var markdownPreview: String {
        var text = self
        text = text.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "`[^`]*`", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "[*_]{1,2}([^*_]+)[*_]{1,2}", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\n{2,}", with: "\n", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
