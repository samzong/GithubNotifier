## 2024-05-22 - Regex overhead in Rule Engine
**Learning:** `NSRegularExpression` compilation is expensive and should be avoided in hot paths if simple string operations can suffice.
**Action:** Always check if a pattern can be resolved with `hasPrefix`, `hasSuffix`, or `contains` before reaching for Regex, especially in loops.
