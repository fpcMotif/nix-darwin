## 2024-08-15 - Replace O(n²) string replacement loop
**Learning:** Collapsing continuous whitespace using a loop like `while '  ' in text: text = text.replace('  ', ' ')` has O(n²) worst-case time complexity. This can cause massive performance hits for long strings with many spaces.
**Action:** Use `re.sub(r'\s+', ' ', text)` for C-optimized linear O(n) performance when collapsing whitespace. Note that `re.sub` preserves single leading/trailing spaces, whereas `' '.join(text.split())` strips them entirely.
