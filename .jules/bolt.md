## 2024-04-28 - Batching Home Manager Activation Scripts
**Learning:** Home Manager executes activation scripts (like those setting up agent skills) by spawning multiple `bash` environments, which can be unexpectedly slow when the same library function is called multiple times.
**Action:** Consolidate inputs (e.g., using `targets` attribute set in `mkSyncScript` instead of mapping) to produce a single bash script loop per activation phase, drastically reducing execution overhead in `.nix` scripts.
