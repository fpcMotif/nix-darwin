## 2024-08-22 - Optimizing Python string manipulation
**Learning:** Collapsing continuous whitespace using a loop like `while '  ' in text: text = text.replace('  ', ' ')` has an O(n^2) worst-case time complexity. This causes severe performance degradation on large strings with consecutive spaces. Using Python's `re` module with `re.sub(r'\s+', ' ', text)` offers C-optimized linear O(n) performance.
**Action:** Consistently use `re.sub(r'\s+', ' ', text)` when reducing multiple whitespaces to single spaces, especially for input that may have long arbitrary strings of whitespace.
