---
name: floodlight-ci-diagnosis
description: "Diagnose CI failures, Periphery index store mismatches, and timing flakiness in Floodlight and SPM repos"
---

# Floodlight CI Failure Diagnosis & Periphery Index Store Workaround

## Context
When diagnosing CI failures in the Floodlight repository (or SwiftPM projects using Periphery and sanitizer runs on GitHub Actions macOS 26 runners):

1. **Periphery Index Store Path Mismatch**:
   - In GitHub Actions `Gates` job, `check-dead-code.sh` can fail with:
     ```
     Error: index store path does not exist: .build/arm64-apple-macosx/debug/index/store
     ```
   - Cause: Xcode/SPM version differences on runner images (`xcode-27-arm64`) may output index store data to custom intermediate locations or require explicit `-Xswiftc -index-store-path .build/arm64-apple-macosx/debug/index/store` during build steps before running Periphery.

2. **Runner Throttling on Strict Timing Benchmarks**:
   - `FuzzyMatcherDifferentialTests` and `AssistantRunSessionTests` have strict execution bounds (e.g., `< .seconds(2)` or async completion timeouts) that pass locally on bare-metal Apple Silicon (M4 Pro) but can intermittently fail on shared virtualized CI runners.
   - When diagnosing PR failures, compare run history against the latest `main` branch runs using `gh run list --branch main` and `/scripts/ci-failures.ts` before assuming PR code changes caused the failure.

3. **Jujutsu (`jj`) Inspection for Swift/UI Commits**:
   - Use `jj diff -r <commit_id> [path]` to inspect atomic hunks.
   - Colocated git/jj workspaces may encounter large untracked `.scratch` test artifacts (>1MB) that trigger `Refused to snapshot some files`. Ensure scratch and bundle artifacts are properly gitignored or scoped.
