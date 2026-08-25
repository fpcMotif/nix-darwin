## 2024-08-25 - Python String Whitespace Collapsing Performance
**Learning:** Collapsing continuous whitespace using a loop like `while '  ' in text: text = text.replace('  ', ' ')` has O(n^2) worst-case time complexity, which scales poorly on long strings.
**Action:** Use `re.sub(r'\s+', ' ', text)` for C-optimized linear O(n) performance, keeping in mind `re.sub` preserves single leading/trailing spaces whereas `' '.join(text.split())` strips them entirely.
