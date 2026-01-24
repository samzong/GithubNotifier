## 2024-05-23 - Regex Compilation Overhead
**Learning:** `RuleEngine` was compiling a `NSRegularExpression` for every wildcard match, even for simple prefix/suffix patterns. This is a significant bottleneck when filtering many notifications against many rules.
**Action:** Use `String.hasPrefix`, `String.hasSuffix`, and `String.contains` for simple wildcard patterns (`foo*`, `*bar`, `*baz*`). Only fall back to Regex for complex patterns.

## 2024-05-24 - String Allocation in Rule Evaluation
**Learning:** `RuleEngine` was allocating new strings using `.lowercased()` for every condition check (equality, inequality, and wildcards). This creates significant memory churn during batched rule evaluation.
**Action:** Use `String.caseInsensitiveCompare(_:)` for equality checks and `String.range(of:options:)` with `.caseInsensitive` for wildcard patterns to compare strings in place without allocation.
