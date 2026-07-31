## 2024-05-30 - Parallel Prefetch Pattern
**Learning:** Network calls to prefetch hashes (e.g., `au_prefetch_sri`) in Nix update scripts can bottleneck sequentially. Parallelizing them using background jobs and `wait` significantly reduces update time.
**Action:** Always use temporary directories to store individual hash outputs when parallelizing network prefetches before sequentially applying edits.
