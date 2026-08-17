## 2024-08-17 - O(n^2) Loop when Replacing Whitespace
**Learning:** In Python, collapsing continuous whitespace using a loop like `while "  " in text: text = text.replace("  ", " ")` has O(n^2) worst-case time complexity. Use `re.sub(r"\s+", " ", text)` for C-optimized linear O(n) performance.
**Action:** Use `re.sub` for collapsing whitespace instead of string loop replacement.
