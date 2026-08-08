## 2025-02-12 - O(n^2) Whitespace Collapse
**Learning:** `while "  " in text: text = text.replace("  ", " ")` has O(n^2) worst-case time complexity for collapsing whitespace.
**Action:** Use `re.sub(r"\s+", " ", text)` for C-optimized linear O(n) performance when collapsing whitespace.
