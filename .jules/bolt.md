
## 2026-06-16 - Optimize au_extract_got_hash memory parsing
**Learning:** Replacing a pipeline (`grep | head | sed`) with native Bash regex (`=~`) when parsing strings already loaded into memory yields a measurable performance improvement (~3.8x faster). However, for macOS Bash 3.2 compatibility, the regex string must be assigned to a separate variable (`local re="..."`) first rather than used inline.
**Action:** When extracting data from multiline logs already buffered in a Bash variable, use native regex to eliminate subprocess overhead.
