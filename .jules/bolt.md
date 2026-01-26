## 2024-05-23 - Regex Compilation Overhead
**Learning:** `RuleEngine` was compiling a `NSRegularExpression` for every wildcard match, even for simple prefix/suffix patterns. This is a significant bottleneck when filtering many notifications against many rules.
**Action:** Use `String.hasPrefix`, `String.hasSuffix`, and `String.contains` for simple wildcard patterns (`foo*`, `*bar`, `*baz*`). Only fall back to Regex for complex patterns.

## 2026-01-26 - Caching Derived Notifications
**Learning:** `groupedNotifications` was re-calculating (grouping O(N) + sorting O(G log G)) on every access. Since it is accessed frequently by the UI but updated infrequently (only when notifications change), caching it improves render performance.
**Action:** Use stored properties with `didSet` observers on the source of truth to update derived data, rather than computed properties, for expensive transformations.
