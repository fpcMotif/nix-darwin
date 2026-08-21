## 2024-06-25 - Avoid replace in loop for collapsing whitespace
**Learning:** In Python, collapsing continuous whitespace using a loop like `while '  ' in text: text = text.replace('  ', ' ')` has O(n^2) worst-case time complexity. Use `re.sub(r'\s+', ' ', text)` for C-optimized linear O(n) performance. Note that `re.sub` preserves single leading/trailing spaces, whereas `' '.join(text.split())` strips them entirely.
**Action:** Use regex `re.sub` when collapsing duplicate characters to prevent O(n^2) performance degradation on large strings.
