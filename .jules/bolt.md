## 2024-05-31 - Staging Hashes for Parallelized Fetching
**Learning:** When parallelizing `au_prefetch_sri` calls in auto-update shell scripts, directly updating files concurrently with `au_set_block_hash` can cause race conditions during in-place file modifications.
**Action:** Stage the fetched hashes in a temporary directory (using `mktemp -d` and `wait`) before applying them sequentially with `au_set_block_hash`.
