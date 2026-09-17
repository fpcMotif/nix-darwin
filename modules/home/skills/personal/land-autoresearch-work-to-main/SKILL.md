---
name: land-autoresearch-work-to-main
description: Land issue-scoped changes buried in a concurrent autoresearch harness branch onto main in xediadownloader without dragging unrelated release-flow commits along
---

# Land autoresearch-branch work onto main

Use when a GitHub issue says its implementation sits on `autoresearch/<slug>` ("swept in by the harness") and must land on `main`, while the branch also carries unrelated harness work (bench legs, release-flow fixes).

## Procedure

1. **Map scope first.** For each candidate file, `git log --oneline main..HEAD -- <file>` and `git diff main..HEAD -- <file>` to separate issue-scoped deltas from harness deltas (e.g. `handlers.ts` quietProbe/release-poll edits are release-flow, not hover).
2. **Snapshot everything issue-scoped** to `/tmp/<ticket>/`: modified tracked files AND untracked new files AND `package.json` + `bun.lock`. Untracked files survive checkout; tracked ones don't.
3. **Switch**: `git checkout -f main` — plain checkout aborts on dirty files that differ between branches. Everything needed is in /tmp.
4. **Restore**: copy snapshots back into place. For tracked files whose final state lives in a branch commit (not the working tree), `git checkout <branch> -- <file>`.
5. **Deps**: copy ONLY the deps the landed code needs from the branch's `package.json` diff (e.g. `fast-check` for property tests); drop harness tooling deps (`@effect/language-service`). Run `bun install` to regen `bun.lock`.
6. **Verify provenance**: `git status --short` should list exactly the issue set; spot-check `git diff --stat` vs main matches expectations before editing further.
7. Then proceed normally: TDD follow-ups, scoped vitest, full `bun run check` (fmt/lint/varlock/wxt/tsgo/depcruise/vitest), review, commit on main.

## Landing a whole hardening family (not just one issue's diff)

When the user asks to land a FAMILY of branch commits (e.g. several `fix(release)` commits), do NOT cherry-pick them one by one if any pick assumes infra from an unlanded mixed commit — picks cascade into conflicts (69c3484 needed 9e0e858's orphan-record base). Instead:

1. Confirm zero divergence: `git merge-base main <branch>` should be main's pre-work tip (or reconcile first).
2. `git checkout <branch> -- <whole file family>` (final branch HEAD state), choosing files by dependency family (broadcaster + its tests, clear/*, handlers*, schema).
3. Let `tsgo --noEmit` be the completeness oracle — it names each missing schema field/import the family needs; add those files and repeat until clean.
4. **Re-apply clobbered main-side deltas**: checkout overwrote everything branch-side, so any delta landed on main AFTER the fork inside those same files is silently gone. Diff against the pre-checkout commit (`git diff <prev-main-tip> -- <file>`) and re-apply (e.g. the `capture` trace-source literal + its test from #92 were clobbered by the branch schema and had to be restored).

## Pitfalls

- Concurrent process owns the autoresearch branch — NEVER push/clean/rebase it; leave it as-is.
- Probe strings like `[DEBUG-xxxx]` may have been added AND removed by later harness commits (`git grep <probe> HEAD` + `git log -S` to confirm); don't re-remove what's already gone.
- Edit-tool PUT ranges are inclusive on BOTH ends: replacing through line N silently deletes line N if your body stops one line short (lost `grabUi = null`; lost `const msg = JSON.parse(...)` twice; dropped `expect(cleared).toBe(1)`). Worse: a partial-body replacement leaves the OLD body tail duplicated after your new code (syntax error or double `let cleared`). After EVERY multi-line body replacement, re-read the region and check both for missing tail lines AND leftover duplicate blocks before running anything.
- `sed -i` multi-pattern rewrites mangle parens across call sites — prefer per-site edits for code.
- Test click-counter helpers must attach listeners BEFORE the awaited action runs, not after (a listener added post-await always reads 0).
- Review subagents (`task` with reviewer role) may wedge on their yield protocol producing zero output; if 2/2 stall, read `history://<id>` to confirm, then run both review axes yourself inline rather than retrying.
