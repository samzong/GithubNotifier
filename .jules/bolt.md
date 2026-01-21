## 2024-05-23 - Regex Compilation Overhead
**Learning:** `RuleEngine` was compiling a `NSRegularExpression` for every wildcard match, even for simple prefix/suffix patterns. This is a significant bottleneck when filtering many notifications against many rules.
**Action:** Use `String.hasPrefix`, `String.hasSuffix`, and `String.contains` for simple wildcard patterns (`foo*`, `*bar`, `*baz*`). Only fall back to Regex for complex patterns.

## 2024-05-24 - String Allocation Overhead
**Learning:** `RuleEngine` was calling `.lowercased()` on every field value and pattern for case-insensitive matching. This creates unnecessary `String` allocations in a hot path (filtering loops).
**Action:** Use `caseInsensitiveCompare`, `localizedCaseInsensitiveContains`, and `range(of:options: .caseInsensitive)` to compare strings in-place without allocation.
