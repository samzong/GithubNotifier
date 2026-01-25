## 2024-05-23 - Regex Compilation Overhead
**Learning:** `RuleEngine` was compiling a `NSRegularExpression` for every wildcard match, even for simple prefix/suffix patterns. This is a significant bottleneck when filtering many notifications against many rules.
**Action:** Use `String.hasPrefix`, `String.hasSuffix`, and `String.contains` for simple wildcard patterns (`foo*`, `*bar`, `*baz*`). Only fall back to Regex for complex patterns.

## 2026-01-25 - Rule Evaluation Overhead
**Learning:** Re-evaluating rules inside a loop caused redundant sorting, lowercasing, and regex compilation for every notification.
**Action:** Lifted rule preparation (sorting, compilation) out of the loop using `RuleEngine.prepare(rules:)` to create optimized structures once.
