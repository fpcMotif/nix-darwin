## 2024-08-09 - Python String Replace Loop Bottleneck
**Learning:** Collapsing whitespace using a `while "  " in text:` loop is O(n^2) and can cause severe performance degradation for large strings with many consecutive spaces.
**Action:** Always use `re.sub(r'\s+', ' ', text)` for collapsing whitespace, as it leverages C-optimized linear O(n) performance and significantly speeds up parsing of large payloads.
