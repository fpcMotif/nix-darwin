---
name: compiled-regex-flags-gotcha
description: "Use when debugging a compiled re pattern whose method call passes re.M/re.S etc. as an argument — compiled patterns' methods take pos/endpos there, not flags"
---

# Compiled-regex flag gotcha

When using a PRE-COMPILED pattern (`p = re.compile(...)`), calling
`p.finditer(s, re.M)` / `p.search(s, re.M)` / `p.match(s, re.M)` does NOT apply
the flag. For compiled patterns the extra positional args are
`pos`/`endpos` — character offsets into the string. `re.M` (= 8) silently
becomes "start scanning at offset 8", so `^…$` anchors match almost nothing
and the bug looks like "regex finds no headings/lines".

Fixes:
- Module-level calls accept flags: `re.finditer(pattern_src, s, re.M)`
- Or compile with flags once: `re.compile(src, re.M)`

Same trap applies to `.sub()`, `.split()`, `.match()` on compiled objects.
Symptom to recognize: a regex helper returns empty results only after you
refactored it from `re.finditer(...)` to a pre-compiled object.
