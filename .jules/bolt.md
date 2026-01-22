## 2024-05-23 - Regex Compilation Overhead
**Learning:** `RuleEngine` was compiling a `NSRegularExpression` for every wildcard match, even for simple prefix/suffix patterns. This is a significant bottleneck when filtering many notifications against many rules.
**Action:** Use `String.hasPrefix`, `String.hasSuffix`, and `String.contains` for simple wildcard patterns (`foo*`, `*bar`, `*baz*`). Only fall back to Regex for complex patterns.

## 2026-01-08 - Computed Property Cost in Observable Objects
**Learning:** Computed properties like `groupedNotifications` in `@Observable` classes are re-evaluated on every access. When these properties involve O(N) or O(N log N) operations (grouping and sorting), it causes significant main thread work during UI updates.
**Action:** Convert expensive computed properties to stored properties updated via `didSet` observers on their dependencies. This shifts the cost from "read time" (frequent) to "write time" (infrequent).
