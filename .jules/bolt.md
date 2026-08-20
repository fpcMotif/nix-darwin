## 2024-08-20 - O(n^2) string replacement loop
**Learning:** Using `while '  ' in text: text = text.replace('  ', ' ')` has an O(n^2) worst-case time complexity, which causes significant performance degradation on large strings with consecutive spaces.
**Action:** Use `re.sub(r'\s+', ' ', text)` instead for linear O(n) performance when collapsing whitespace.
