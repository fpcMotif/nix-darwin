## 2024-06-25 - Python Whitespace Collapsing Performance
**Learning:** In Python, collapsing continuous whitespace using a loop like `while '  ' in text: text = text.replace('  ', ' ')` has O(n^2) worst-case time complexity, which can severely degrade performance on large strings (like those found in LLM traces).
**Action:** Use `re.sub(r'\s+', ' ', text)` for C-optimized linear O(n) performance when collapsing whitespace. Note that `re.sub` preserves single leading/trailing spaces, whereas `' '.join(text.split())` strips them entirely, which may affect functional equivalence.
