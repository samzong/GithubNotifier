## 2024-05-23 - Regex Compilation Overhead
**Learning:** `RuleEngine` was compiling a `NSRegularExpression` for every wildcard match, even for simple prefix/suffix patterns. This is a significant bottleneck when filtering many notifications against many rules.
**Action:** Use `String.hasPrefix`, `String.hasSuffix`, and `String.contains` for simple wildcard patterns (`foo*`, `*bar`, `*baz*`). Only fall back to Regex for complex patterns.

## 2024-05-24 - Rule Evaluation Optimization
**Learning:** Re-sorting and filtering rules inside the notification loop caused O(M * N log N) complexity.
**Action:** Lifted rule preparation (filtering/sorting) out of the loop using `prepareRules`, reducing complexity to O(N log N + M * N).
