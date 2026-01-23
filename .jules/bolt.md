## 2024-05-23 - Regex Compilation Overhead
**Learning:** `RuleEngine` was compiling a `NSRegularExpression` for every wildcard match, even for simple prefix/suffix patterns. This is a significant bottleneck when filtering many notifications against many rules.
**Action:** Use `String.hasPrefix`, `String.hasSuffix`, and `String.contains` for simple wildcard patterns (`foo*`, `*bar`, `*baz*`). Only fall back to Regex for complex patterns.

## 2024-05-24 - Cached Derived Properties
**Learning:** `groupedNotifications` was a computed property doing O(N log N) work on every access. Since it is used in SwiftUI views, this caused frequent re-computations.
**Action:** Converted to a stored property updated via `didSet` on the source `notifications` array. This ensures O(1) read access.
