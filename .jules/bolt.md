## 2024-05-23 - Regex Compilation Overhead
**Learning:** `RuleEngine` was compiling a `NSRegularExpression` for every wildcard match, even for simple prefix/suffix patterns. This is a significant bottleneck when filtering many notifications against many rules.
**Action:** Use `String.hasPrefix`, `String.hasSuffix`, and `String.contains` for simple wildcard patterns (`foo*`, `*bar`, `*baz*`). Only fall back to Regex for complex patterns.

## 2024-05-24 - String Allocation & Eager Evaluation
**Learning:** `RuleEngine` was allocating new strings via `lowercased()` for every condition check, and eagerly evaluating all conditions using `map` before logic checks. This creates unnecessary memory pressure and CPU cycles.
**Action:** Use `caseInsensitiveCompare` to avoid allocations and use `allSatisfy`/`contains` directly on collections for short-circuiting.
