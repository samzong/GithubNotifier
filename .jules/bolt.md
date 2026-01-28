## 2024-05-23 - Regex Compilation Overhead
**Learning:** `RuleEngine` was compiling a `NSRegularExpression` for every wildcard match, even for simple prefix/suffix patterns. This is a significant bottleneck when filtering many notifications against many rules.
**Action:** Use `String.hasPrefix`, `String.hasSuffix`, and `String.contains` for simple wildcard patterns (`foo*`, `*bar`, `*baz*`). Only fall back to Regex for complex patterns.

## 2024-10-27 - Repeated Rule Sorting
**Learning:** `RuleEngine.evaluate` sorts rules by priority on every call. `NotificationService` calls this in a loop, leading to redundant sorting (O(N * M log M)).
**Action:** Lifted rule sorting out of the evaluation loop using `prepareRules`, reducing complexity to O(M log M + N * M).
