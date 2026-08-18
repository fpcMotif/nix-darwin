
## 2024-08-18 - Avoid O(n²) string replacements in Python
**Learning:** Collapsing continuous whitespace using a loop like `while '  ' in text: text = text.replace('  ', ' ')` has an O(n²) worst-case time complexity because it rescans the string multiple times. In agent traces, large prompts with significant whitespace can cause this block to heavily degrade performance.
**Action:** Always prefer `re.sub(r'\s+', ' ', text)` for collapsing whitespace, as it executes in C-optimized O(n) time and simplifies the code by implicitly handling newlines and carriage returns.
