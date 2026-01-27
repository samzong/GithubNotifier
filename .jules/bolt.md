## 2024-05-23 - Regex Compilation Overhead
**Learning:** `RuleEngine` was compiling a `NSRegularExpression` for every wildcard match, even for simple prefix/suffix patterns. This is a significant bottleneck when filtering many notifications against many rules.
**Action:** Use `String.hasPrefix`, `String.hasSuffix`, and `String.contains` for simple wildcard patterns (`foo*`, `*bar`, `*baz*`). Only fall back to Regex for complex patterns.

## 2024-05-23 - Rule Sorting Bottleneck
**Learning:** `RuleEngine.evaluate` was re-sorting and re-filtering the entire rule list for every single notification, causing O(N log N) overhead per notification.
**Action:** Lift invariant operations (sorting/filtering) out of loops. Added `prepareRules` to perform this once, allowing O(1) rule list access inside the loop.
