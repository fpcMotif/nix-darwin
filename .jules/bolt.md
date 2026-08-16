## 2024-05-24 - O(n^2) worst-case using while loop for replacing spaces
**Learning:** Using `while "  " in text: text = text.replace("  ", " ")` to collapse contiguous spaces has an O(n^2) worst-case time complexity, scaling poorly with a large number of spaces, unlike linear C-optimized implementations.
**Action:** Use `re.sub(r'\s+', ' ', text)` to collapse consecutive whitespace into a single space, yielding a significant speedup for large blocks of spaces while correctly keeping linear complexity.
