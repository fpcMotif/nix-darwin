## 2024-05-23 - Python Whitespace Collapse Performance
**Learning:** In Python, collapsing continuous whitespace using a loop like `while '  ' in text: text = text.replace('  ', ' ')` has O(n²) worst-case time complexity, causing significant slowdowns on large inputs with many spaces. Using `re.sub(r'\s+', ' ', text)` provides C-optimized linear O(n) performance.
**Action:** Use `re.sub(r'\s+', ' ', text)` to collapse continuous whitespace instead of while-loops with string replacements.
