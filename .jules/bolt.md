## 2025-02-24 - Avoid O(n^2) string replacements
**Learning:** Using `while "  " in text: text = text.replace("  ", " ")` in python is O(n^2) worst case and extremely slow for large inputs with many spaces, taking ~2.5ms for 50,000 spaces. `re.sub(r'\s+', ' ', str(text))` is significantly faster (~0.5ms) and correctly preserves leading/trailing single spaces unlike `str.split()`.
**Action:** Use regex `re.sub(r'\s+', ' ', str)` for reducing continuous whitespace instead of iterative `str.replace`.
