## 2024-08-24 - Optimizing Whitespace Trimming
**Learning:** Collapsing continuous whitespace using a loop like `while '  ' in text: text = text.replace('  ', ' ')` has $O(n^2)$ worst-case time complexity, while using `re.sub(r'\s+', ' ', text)` provides linear $O(n)$ performance as well as being cleaner to read. `re.sub` also preserves single leading/trailing spaces as intended, which `' '.join(text.split())` does not do.
**Action:** Use `re.sub(r'\s+', ' ', text)` when collapsing multiple spaces to avoid $O(n^2)$ complexity overheads for large texts with extensive contiguous spaces.
