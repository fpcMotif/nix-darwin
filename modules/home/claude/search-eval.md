# Code search tier evaluation (2026-09-08, M4 Pro, ~/devv)

Evidence behind the "Code search routing" block in CLAUDE.md. Tools: codedb 0.2.5854, fff-mcp 0.10.0 (not 0.10.5), tgrep 1.0.4, ripwire 0.5.0, ripgrep 15.2.0. Tree: 65,163 files rg walks (18,924 in node_modules; ~/devv is not a git repo), 59,527 text files tgrep indexes, 16,375 files codedb indexes (skips node_modules and files > 2 MiB).

## Latency (hyperfine mean, warm cache, whole ~/devv)

| Query | codedb CLI | fff MCP | tgrep (indexed) | rg (14 threads) | rg -j6 | ripwire --grep |
|---|---|---|---|---|---|---|
| Config (-w) | word 4.1 ms, 27,064 hits, 1.7 MB uncapped | ~40 ms, "20/51 shown" (true 24,528 lines) | 185 ms | 1,752 ms | 819 ms | 4,430 ms |
| TODO | search 2.4 ms, 50 of 1,238 | | 80 ms | 2,037 ms | | |
| export interface | search 2.4 ms, 50 of 9,539 | "20/51 shown" | 156 ms | 1,830 ms | | |
| WeComError (absent) | 2.3 ms, 0 | 69 ms, "0 exact matches. 50 approximate" | 21 ms, 0 | 1,890 ms, exit 1 | | 3,850 ms, 0 + did-you-mean |
| pub (async )?fn \w+\( | 2.8 ms, 50 of 14,220 (regex works; claim "fails syntax" not reproduced) | "20/50 shown" (true 14,220) | 101 ms, 14,220 | 1,870 ms, 14,220 | | |

Setup costs: tgrep index 6.7 s / 672 MB for ~/devv, 0.1 s / 9.6 MB per repo. codedb MCP loads its 627 MB snapshot for ~12 s after session start (500 MB RSS); the CLI is instant. ripwire re-parses per call: ~4 s at umbrella scale even with --cache, 50-200 ms per repo. Inside one 600-file repo: rg 15 ms, tgrep 5 ms, codedb explain 2.5 ms, ripwire --callers 47 ms; latency is not the argument there, token shape is.

rg thread scaling on this machine (APFS syscall contention, sys time 17 s at 14 threads): -j2 1.00 s, -j4 0.84, -j6 0.82, -j8 1.36, default 1.75-1.97 s. ~/.config/ripgrep/agent-config sets --threads=6, --max-columns=240, and excludes node_modules; it is applied only in Claude Code's Bash via env.RIPGREP_CONFIG_PATH.

## Failure modes

- A1 codedb 2 MiB cap: CONFIRMED. A token unique to Design Business Client Interface/landing-page.html (4.2 MB) is found by rg and tgrep (39 ms), not by codedb search or word.
- A2 multiline: CONFIRMED. codedb search --regex 'struct \w+ \{\n\s+pub' = 0; tgrep -U = 526 files in 129 ms; rg -U = 526 files in 1.4 s. Caveat: tgrep -U -c reports 3,064 (lines) vs rg 1,532 (matches).
- A3 context/caps: CONFIRMED. No -C/-A/-B ("unexpected extra argument"); search caps at 50, --max-results up to 200; word is uncapped.
- B1 fff cap: CONFIRMED. Hard cap 50 (shown as "20/51"), so 24,528 real lines read as 51.
- B2 fff false positives: PARTLY. Output is labelled "0 exact matches. 50 approximate:"; the hazard is a model that skims the label.
- C1 CI: PARTLY. At 65k files, 50 literal checks: tgrep 6.7 s + 50 x 0.22 s = 18 s vs rg default 95 s (5x) or rg -j6 31 s (1.8x). In a 600-file repo rg (0.73 s / 50) beats tgrep (1.7 s / 50). The 11x claim assumed 30 ms tgrep queries; common tokens cost 80-220 ms.
- C2 ripwire gates: CONFIRMED on a real diff (throwaway worktree, isOversizeAttachment gained a required parameter): --edit-check = contract-change, 6/6 callers incompatible; --test-gate exit 4 (3 tests to run, 16 untested symbols); --quality-delta exit 0; --quality-delta=BASE..HEAD 1.2 s; --pr-context 0.45 s, 9.3 KB.

Additional: the ~/devv codedb index mixes three checkouts of outlook-feishu-bridge (explain returned 29 call sites, 8 real); a per-repo root (`codedb <repo> ...` or MCP project=) fixes it. codedb context (hybrid default) sends ~3 KB of snippets to a remote reranker; semantic=local exists; with identifiers seeded it is excellent, with words only it missed the target in both modes. ripwire --for="words" found MAX_ATTACHMENT_BYTES at rank 1 in 0.17 s. ripwire XML legends are 60-80% of output bytes (rw strips them: callers 3,987 -> 842 B). ripwire --uses on a TypeScript constant returns 0; --callers misses calls inside anonymous callbacks. The previous hook codedb-block-legacy.sh blocked rg for an opus agent, which fell back to perl one-liners and produced wrong line numbers; other agents bypassed it with `cd X && rg`.

## Agent trials (subagent_tokens / tool calls; all 18 answers correct on core facts)

Tasks on outlook-feishu-bridge: T1 signature-change caller audit of isOversizeAttachment; T2 "where is an attachment decided too large, limit, enforcement sites, boundary test, user message". Baseline = Grep/Read/rg only. v1 = 13-row routing table. v2 = the shipped procedure (tg, rw, codedb explain/outline/read -L, count-first, batching). Calibration: an agent that does nothing costs 35.35k; three trivial tool calls add ~6k (~2k per round trip).

| Model | Task | Baseline | v1 | v2 |
|---|---|---|---|---|
| haiku | T1 | 69.7k / 16 | 62.8k / 21 | 67.0k / 19 |
| sonnet | T1 | 111.0k / 17 | 102.8k / 25 | 90.7k / 17 |
| opus | T1 | 102.5k / 16 | 82.5k / 14 | 81.6k / 8 |
| haiku | T2 | 76.0k / 19 | 80.9k / 24 | 68.2k / 17 |
| sonnet | T2 | 96.7k / 13 | 128.1k / 29 | 117.3k / 22 |
| opus | T2 | 99.1k / 15 | 95.0k / 22 | 92.2k / 8 |

Marginal over the 35.35k floor, v2 vs baseline: opus -23%, haiku -9%, sonnet 0% (sonnet re-verifies with Reads regardless). Opus v2 made 8 tool calls per task (24 commands batched), read 0-1 whole files, and returned ~300-600 output lines vs ~1,000-1,300. Haiku ignored "read spans" in prose (5 whole-file Reads per task), hence the read-guard hook. Routed sonnet runs took ~3x longer wall time.

## What is installed

- ~/.claude/hooks/search-guard.sh  PreToolUse(Bash): denies uncapped `codedb word`, rg/grep launched at the ~/devv root with no sub-path, cat/bat of files > 300 KB, and a leading rg/grep/tg listing with 4+ alternations and no narrowing. Everything else passes. SEARCH_GUARD_OFF=1 disables.
- ~/.claude/hooks/read-guard.sh  PreToolUse(Read): denies a limit-less Read of a code file > 200 lines (READ_GUARD_MAX_LINES) and names the outline + span commands; offset+limit is the escape hatch.
- ~/.claude/hooks/search-warmup.sh  SessionStart: builds the per-repo tgrep index and ripwire cache in the background under ~/.cache, warms codedb, injects one context line, warns when cwd is the umbrella.
- ~/.local/bin/tg (tgrep with a per-repo index kept out of the repo, root from the path argument) and ~/.local/bin/rw (ripwire with node_modules excluded, legends stripped, exit codes preserved).
- ~/.config/ripgrep/agent-config, wired via settings.json env.RIPGREP_CONFIG_PATH.
- ~/.claude/settings.json: PreToolUse Bash hook codedb-block-legacy.sh -> search-guard.sh; SessionStart codedb-warmup.sh -> search-warmup.sh; PreToolUse Read read-guard.sh added. Backups: ~/.claude/backup-2026-09-08-search-routing/.
- ~/nix-config/modules/home/claude/CLAUDE.md: "Search" section replaced by "Code search routing" (uncommitted). ~/.claude/CLAUDE.md is a store symlink; rebuild (darwin-rebuild switch) to apply.
- codedb per-repo index for outlook-feishu-bridge (~/.codedb/projects/57c16973635265dc). Caches: ~/.cache/tgrep/{devv-348eed37 (547 MB), outlook-feishu-bridge-beae2311}, ~/.cache/ripwire/outlook-feishu-bridge-beae2311.bin.

Revert: `cp ~/.claude/backup-2026-09-08-search-routing/settings.json ~/.claude/settings.json; git -C ~/nix-config checkout modules/home/claude/CLAUDE.md`, and delete the three hook scripts and the two wrappers.

To make the hooks and wrappers reproducible, add to claude.nix's home.file: `".claude/hooks/search-guard.sh" = { source = ./claude/hooks/search-guard.sh; executable = true; };` (same for read-guard.sh, search-warmup.sh) and `".local/bin/tg"`, `".local/bin/rw"`, `".config/ripgrep/agent-config"`, after copying the files into modules/home/claude/.

## CI (GitHub Actions) sketch
(Superseded by the validated recipe under "Corrections after external review" below; kept for the numbers.)

```yaml
- run: ripwire . --quality-delta=${{ github.event.pull_request.base.sha }}..HEAD --exclude=node_modules --json > quality.json   # exit 2 = a pre-existing symbol got worse
- run: |
    changed=$(git diff --name-only ${{ github.event.pull_request.base.sha }}..HEAD | paste -sd, -)
    ripwire . --test-gate="$changed" --exclude=node_modules --json > test-gate.json || [ $? -eq 4 ]   # 4 = tests to run / untested radius; parse tests_to_run
- run: tgrep index . && for p in TODO FIXME 'as any' '@ts-ignore' debugger; do tgrep -c "$p" src; done   # worth it only above ~5k files; below that plain rg
```

## Size scaling, rg vs tgrep (added after the "500-5k files: tg" claim was challenged)

hyperfine means, `-n TODO`, rg with the agent config (6 threads, node_modules excluded), tgrep with a prebuilt index; `tg` is the wrapper (adds ~25 ms fixed: git rev-parse, shasum, staleness check).

| Files (rg walk) | rg | tg wrapper | tgrep raw | index build / size |
|---|---|---|---|---|
| 606 (outlook-feishu-bridge) | 12.5 ms | 32 ms | 4.7 ms | 0.1 s / 9.6 MB |
| 1,432 (bun-native-effect) | 22 ms | 36 ms | 8.3 ms | |
| 3,038 (gosh-my-pi) | 38 ms | 38 ms | 11.5 ms | |
| 3,786 (superzed) | 43 ms | 45 ms | 18 ms | |
| 19,029 (feishudoc) | 174 ms | | 6-21 ms | 2.3 s / 268 MB |
| 65,163 (~/devv) | 600-820 ms (1.75-2.0 s without config) | | 21-185 ms | 6.7 s / 547 MB |

rg costs about 12 us per file here and stays under 200 ms up to ~20k files; below ~5k files rg and tg are indistinguishable and rg has no index to go stale. tgrep's latency advantage only becomes something an agent can feel (hundreds of ms per query, times 5-15 queries per task) above roughly 20-30k files. The guard denies rg at the ~/devv root because of the output flood and node_modules, not because of latency. The earlier per-stage table that put tg ahead at 500-5k files was an extrapolation and is withdrawn.

## Corrections after external review (2026-09-08)

A second reviewer audited the original benchmark brief against the tools' sources. Each point was checked here; verdicts below are measurements, not the reviewer's text.

### What each number measures
| Layer | Fixed task | Metric used here | Where |
|---|---|---|---|
| Exact retrieval | same literal/regex, whole tree | wall time, hit counts, output bytes | Latency table, size scaling |
| Navigation | first useful file/symbol for a name or a phrase | did r=1 / first result land on the target | ripwire --for, codedb context notes |
| Coding task | same question, same repo, same ground truth | subagent_tokens, tool calls, correctness | Agent trials |
The latency table mixes tools that do different jobs (fff shows 20 of a 50-capped set; codedb search caps at 50; rg/tgrep enumerate). Read it as "time to the answer each tool gives", never as engine speed.

### Coverage per engine on ~/devv (the corpus each number ran over)
| Engine | Files considered | Excluded |
|---|---|---|
| rg default | 65,163 (`rg --files`), includes 18,924 under node_modules and the 627 MB codedb.snapshot | hidden, gitignored inside git repos, binary |
| rg agent config | same minus node_modules, .tgrep, *.snapshot; 240-column cap | |
| tgrep | 59,271 text files | binary (5,635 + 256 by content), 1 file > 64 MiB |
| codedb (umbrella index) | 43,169 files tracked, 16,375 with trigram entries | node_modules, > 2 MiB (skipped entirely), 1-2 MiB (no trigram; search falls back to a 2-7 s scan on first query, then cached; word index instant) |
| ripwire | parsed 15 languages; 63 files dropped as oversize | unsupported extensions scanned only by --grep as "unindexed" |
| fff | live scan of the tree, hidden dirs included (it indexed .tgrep/) | |

### Lifecycle (cold vs warm), measured
| Scenario | codedb | tgrep | ripwire | fff |
|---|---|---|---|---|
| No index, first query | reindex 4.3 s (umbrella) | build 6.7 s (65k), 2.3 s (19k), 0.1 s (600) | parse 4.4 s (65k), 0.2 s (600) | startup scan + RAM content index |
| Disk index, new process | CLI 2-4 ms; MCP server 12 s to load the 627 MB snapshot (status reports 0 files until then) | 5-185 ms | cache 227 MB, 3.8 s at 65k; 70 ms at 600 | n/a |
| Persistent service | MCP warm ~ms | `tgrep serve` not tested | `--mcp` not tested | MCP warm 8-120 ms |
| Editing loop | polling; `hot` lists recent files | `tg` re-indexes every call up to 2k files (no-change reindex ~100 us/file: 60 ms at 606, 381 ms at 3.8k, 2.3 s at 19k), else 10-min window; new file found immediately, deleted file no ghost hit | content-hash cache | watcher |

### Claims from the brief, final verdicts
- "tgrep regex 1,690 ms": that was a no-index run. Indexed: 101 ms for `pub (async )?fn \w+\(` (14,220 hits), because the planner keeps `pub`, `fn`, `(` as required trigrams and verifies candidates in parallel.
- "codedb --regex fails syntax": false. It ran in 2.9 ms and returned 50 of 14,220 (cap), and 0 for the multiline pattern (line-scoped).
- "fff returns 50 fuzzy hits as if exact": overstated. Output reads "0 exact matches. 50 approximate:" and shows 3. The hazard is a model skimming past the label, and the 50 cap on real enumerations (24,528 lines shown as "20/51").
- "codedb 2 MiB cap": confirmed for > 2 MiB (4.2 MB HTML token: rg/tgrep hit, codedb search and word miss). 1-2 MiB: found, slow first time (see coverage).
- "tgrep 11x in CI": at 65k files, 50 checks: tgrep 6.7 s build + 11 s = 18 s; rg -j6 31 s; rg default 95 s. Inside a 600-file repo rg wins (0.7 s vs 1.7 s). With the brief's own parameters the break-even is q > 6.6/(1.8-0.05) = 3.8 queries and T(50) = 9.1 s, not 8.1 s.
- "--quality-delta blocks new debt": no. Exit 2 only when a pre-existing symbol got materially worse and is unacked; new-symbol rows print but never gate; renames read as new. "--test-gate blocks untested changes": no. Exit 4 names tests to run and an untested radius; it never runs tests and cannot know you did.
- Token accounting: subagent_tokens is the harness's own usage, not an estimate. Base cost of an idle subagent 35.4k; each trivial round trip ~2k. The gains measured came from answer shape (bodies + callers in one call, spans instead of files, legends stripped: 75% fewer ripwire bytes), not from engine latency.

### CI recipe, validated on this repo
Base for a PR is not implicit: --quality-delta compares working tree vs HEAD, --test-gate reads the current diff. Validated flow (HEAD stays at the merge-base, the PR tree is restored on top):
```bash
BASE=$(git merge-base "$PR_BASE_SHA" "$PR_HEAD_SHA")
git worktree add --detach "$WT" "$BASE"
rw "$WT" --quality-baseline                       # baseline on the clean base
git -C "$WT" restore --source="$PR_HEAD_SHA" --staged --worktree -- .
rw "$WT" --quality-delta > quality.xml;  qd=$?    # 2 = pre-existing regression, else 0
rw "$WT" --test-gate     > gate.xml;     tg=$?    # 4 = obligations listed, 0 = none, other = tool failure
```
Checked: after restore, `git rev-parse HEAD` = merge-base and `git diff --cached --stat` = the PR's 6 files; both gates ran (0/0 on a config-only PR; 2/4 shapes were exercised earlier on a synthetic signature change). Rules: treat any exit other than {0,2} / {0,4} as tool failure, never `|| true`; do not exec `run="..."` strings from the report, map named test files to your own runner; run PR checks under `pull_request`, not `pull_request_target`; skip actions/cache for the index (fresh build 0.1-6.7 s beats a download); protect .ripwire_quality_baseline and ack files from the restore step.

### Not done (would change conclusions if done)
- Crossed design: same candidates x {bare lines, fixed window, function bundle} x {rg, tgrep, codedb}. The trials varied both at once, so "bundle beats bare lines" and "engine X" are confounded.
- Consistency stress test after a rebase (create/delete/rename/same-size rewrite/truncate/ignore change): p95 of "edit to visible", misses, ghost hits.
- A result contract (searched set, completeness, snapshot id) across tools; today only ripwire --grep emits complete=/corpus_oversize=.
- Version 2 routing trials: 1 of 6 agents finished (haiku caller audit, 67.0k tokens, 19 calls) before the session ended.

## Round 2 candidates: zoekt, reflex, trigrep (2026-09-08, test only, not wired)

Installed: zoekt (go install, 5 binaries, ~200 MB), reflex 1.6.1 (`bun install -g reflex-search`, binary `rfx`), trigrep 0.1.2 (`cargo install --git`, 13 s build). universal-ctags for zoekt via `nix shell nixpkgs#universal-ctags`.

### Index build, size, coverage
| Engine | outlook-feishu-bridge (606 files by rg) | ~/devv umbrella | Index location |
|---|---|---|---|
| zoekt git mode | REFUSED: go-git rejects `extensions.worktreeConfig`, which Claude Code worktrees enable; 17 of 42 repos here | `zoekt-local-sync`: 25 repos, 26 s, 374 MB | ~/.cache (any dir) |
| zoekt dir mode + ctags | 0.75 s, 19 MB, 902 files (docs included) | 26 s, 2.1 GB, 92,665 files (hidden dirs included) | ~/.cache |
| reflex | 2.4 s, 16 MB, 421 files: supported-language sources only, no .md/.json/.yaml/.html | not built (5 ms/file; 3k-file repo: 8.6 s, 94 MB) | `.reflex/` INSIDE the repo (untracked) |
| trigrep | 0.09 s, 8.3 MB, 577 files | 11.5 s, 578 MB, 58,558 files (node_modules included: umbrella is not a git repo) | `.trigrep/` INSIDE the target dir |
| tgrep (reference) | 0.1 s, 9.6 MB | 6.7 s, 547 MB, 59,271 | ~/.cache via `tg` |

### Per-repo latency and hit lines (hyperfine mean, 5 runs; rg with agent config)
| Query | rg | tgrep | zoekt CLI | rfx CLI | trigrep | codedb search |
|---|---|---|---|---|---|---|
| isOversizeAttachment | 16 / 13.6 ms | 16 / 5.7 ms | 16 / 38.6 ms | 15 / 142 ms | 17 / 8.6 ms | cap / 2.9 ms |
| TODO | 13 / 23 ms | 13 / 6.1 ms | 19* / 38 ms | 0** / 130 ms | 13 / 4.5 ms | 19 / 2.6 ms |
| export interface | 137 / 20 ms | 137 / 8.8 ms | 137 / 38 ms | 135 / 146 ms | 137 / 12 ms | cap / 2.6 ms |
| WeComError (absent) | 0 / 22 ms | 0 / 4.8 ms | 0 / 38 ms | 0 / 139 ms | 0 / 5.2 ms | 0 / 2.7 ms |
| `export (async )?function \w+\(` | 477 / 23 ms | 477 / 18 ms | 0*** / 37 ms | 445 / 110 ms | 477 / 15 ms | cap / 2.4 ms |
\* zoekt is case-insensitive by default (`case:yes` to fix). \*\* all 13 TODOs live in .md/.html/.json, which reflex does not index. \*\*\* zoekt's query grammar owns spaces and quotes: spaces split AND atoms, quoted strings eat backslashes; write `export.(async.)?function.\w+\(` (507 hits). The 17th trigrep hit is real: a docs file with 2 NUL bytes that rg and tgrep silently treat as binary (`rg -a` finds 17).

### Umbrella latency (coverage differs per engine, see table above)
| Query | rg -j6 | tgrep | zoekt CLI (2.1 GB index) | trigrep |
|---|---|---|---|---|
| -w Config | 3,037 / 1.25 s | 3,037 / 180 ms | 5,772 / 78 ms | 3,245 / 282 ms |
| TODO | 760 / 1.10 s | 760 / 61 ms | 2,479 / 70 ms | 1,239 / 112 ms |
| export interface | 5,063 / 1.03 s | 5,063 / 154 ms | 8,816 / 81 ms | 9,539 / 534 ms |
| WeComError | 0 / 1.23 s | 0 / 18 ms | 0 / 88 ms | 0 / 184 ms |
| `pub (async )?fn \w+\(` | 14,213 / 672 ms | 14,213 / 111 ms | grammar | 14,220 / 143 ms (1,839 candidate files of 58,558) |
zoekt as a persistent server (`zoekt-webserver -rpc`, JSON API): server-side 0-1 ms for selective queries, 110 ms for 8,816 matches; ~50 ms wall per HTTP call. That is the only configuration here that beats tgrep at scale, at 4x the disk.

### Freshness (new file, then deleted, without reindex)
| | new file seen | reindex cost | after reindex | deleted file ghost hit |
|---|---|---|---|---|
| tg | yes (re-indexes per call) | 60 ms | yes | no |
| trigrep | no (`status` still says up to date vs HEAD) | 0.12 s | yes | no (verifies on disk) |
| zoekt dir | no | 0.38 s (full rebuild) | yes | YES until rebuilt |
| reflex | no | 1.8 s incremental, and the untracked file was STILL missing; `rfx index -f` (2.4 s) found it | after -f | no |

### Answer shape for "definition + every use of isOversizeAttachment" (bytes)
codedb explain 1,713 (def body + 8 call sites + enclosing fn) | rw --callers 842 (6 callers + tested flags) | rfx --symbols --json 435 (definition only, with body span) | rfx MCP find_references 2,383 (definition + 15 references incl. imports/re-exports, no enclosing fn) | rfx list_locations 551 (file:line only) | rfx count_occurrences 73 | zoekt plain 1,710, ranked with the definition first (ctags) | zoekt -jsonl 6,228 | trigrep --json 2,627 | rg -n 1,742.
reflex also answers file-level `deps --reverse` (6 importers of attachmentPolicy.ts) and `find_hotspots/circular/unused`, which none of the other engines do.

### Verdict
- zoekt: the best engine at umbrella scale only as a long-running server, and it cannot open this machine's worktree-enabled repos in git mode. Directory mode works but rebuilds fully (26 s, 2.1 GB). Not for a laptop editing loop; right tool for a shared index of many repos.
- trigrep: a leaner tgrep (grep-compatible output, verified-on-disk hits, good planner) with two costs: index inside the target dir (pollutes git status, fff, codedb) and 2-4x slower than tgrep at 65k files. No multiline, no -U. Nothing it does better than tg here.
- reflex: the only one with symbols + references + file dependency graph in one binary and a well-shaped MCP (list_locations at 551 bytes is the cheapest enumeration seen). Costs: source-only coverage (docs/configs invisible), 130-215 ms per CLI call, in-repo `.reflex/`, and the incremental-reindex miss on a new file. Worth a second look via its MCP for TypeScript-heavy repos; not a replacement for tg or codedb today.
Cleanup done: umbrella indexes removed; `~/.cache/zoekt/ofb` (19 MB) and the three binaries kept.

## Round 3: zg (zvec-grep 0.2.2), semantic + lexical hybrid, tested 2026-09-08

Node CLI (`~/.local/bin/zg`), local embedding model `local/potion-code-16m-v2` (model2vec, 256 dims, 32 MB one-time download), index inside the repo at `.zvec-grep/`. Remote models exist but stay off unless `--allow-remote`. MCP over stdio works for Claude Code (`claude mcp add zg -- zg server --stdio`); NOT installed via `zg install`, which also writes managed rules into agent config.

| | 606-file repo | 3,013-file repo | implied for 65k files |
|---|---|---|---|
| Index build (local model, no download) | 4.3 s, 5,153 entities, 33 MB | 38 s, 55,601 entities, 299 MB | ~14 min, ~6 GB |
| Query, direct mode | 536 ms hybrid, 568 ms fts, 166 ms managed rg | 984 ms fts | seconds |
| Query, server mode | 265 ms hybrid, 246 ms fts (Node client startup dominates) | | |
| Freshness | server background refresh saw a new file within 5 s; `--refresh wait` immediate; incremental `zg index` 0.96 s; deleted file ghosts with refresh off | | |

Retrieval quality on the ground-truth task (decision function isOversizeAttachment, constant MAX_ATTACHMENT_BYTES):
- The full natural-language question returned 10 hits, all prose (a flow-exploration note, a handoff, ADR-0004 "> 20 MB attachments"): topically right, code target absent. ripwire --for had the constant at rank 1; codedb_context with identifiers seeded had both.
- Code-vocabulary phrasings: "attachment size limit" and "maximum attachment bytes" landed on attachmentPolicy.ts / isOversizeAttachment (lexical side carried it); "oversize attachment check" and "is attachment too large" missed.
- Vector-only paraphrase with no shared tokens ("throttling backoff when the API says slow down") put convex/feishu/call.ts:49-71 (the rate-limit retry) at rank 1, where the fts route alone did not surface call.ts. That is the one measured case where the vector route added something. A second paraphrase ("avoid sending the same document twice") returned stress-test report HTML/JSON for zg and unrelated components for ripwire: both missed.
- `--fts SYM` groups hits by enclosing symbol with the span (definition 122-124, then sendableMailAttachments 36-42, uploadRejectionReason 128-137, useIntakeAttachments 150-253): the same shape as codedb explain + rw --callers, in one call, and with `--preview short` it inlines the bodies (5.6 KB for 11 hits; 12 KB with full previews).
- Absent symbol: CLI `--fts WeComError` says "hits: 0 / No matches". The MCP tool, given the same word, returned 3.8 KB of vector-only neighbours with no "no lexical match" statement: the fff hazard again, now without the label.
- Docs/report assets (HTML, JSON under docs/reports) dominate vector results; index with `-T html -g '!docs/reports/**'`.

Verdict: the strongest orientation shape of the round-2/3 candidates (enclosing-symbol grouping with bodies, hybrid routing, live refresh in server mode, honest coverage/freshness fields), paid for with 250-1000 ms per query, an in-repo index that grows ~100 KB per file, a 16M-parameter model whose semantic route rarely beats lexical on this corpus, and an MCP answer that does not say "nothing matched". Fair use today: an optional MCP for word-only orientation on a single TS repo, with `preferSymbol` for names; not a text or symbol layer replacement.

### zg correction: per-query latency through the daemon
The 250-550 ms figures above are Node CLI startup per invocation. Through the persistent daemon that Claude Code's MCP entry uses (`zg server --stdio`, daemon `zg server run --mcp-toolset agent`), a search call measured from the client side takes 9-26 ms for 1.5-3.5 KB answers (hybrid "attachment size limit" 26 ms, `isOversizeAttachment` 16 ms, synonym paraphrase 13 ms, `export interface` 10 ms, `TODO` 9 ms). Verified from Claude Code itself: `mcp__zg__zvec_grep_search` with `root` set works; adding `fts: "<symbol>"` beside a prose `query` returns prose hits and the code definition + caller functions in one answer. Daemon sockets are loopback only (lsof); embedding model is local model2vec potion-code-16M-v2 at ~/.zvec-grep/models (32 MB); remote Qwen models are listed but not authorized and not used. Index build cost and the in-repo `.zvec-grep/` size are unchanged.
