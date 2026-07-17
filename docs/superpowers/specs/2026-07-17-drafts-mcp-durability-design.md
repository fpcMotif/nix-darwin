# Drafts MCP Durability — Design

Date: 2026-07-17
Scope approved: Full A + B + C (user, this session)
Status: awaiting spec review

## 1. Problem and evidence

The Drafts MCP bridge failed twice on 2026-07-17, for two different reasons:

1. **Morning ("can't connect"):** Drafts ran windowless → AppKit enabled Automatic Termination → macOS reaped it via SIGTERM every ~60–90s → Apple Events cold-relaunched it headless → tool calls straddling a reap failed or crawled. The MCP handshake itself never failed (~105ms).
2. **Evening ("Not Responding"):** one `every draft whose content contains X` Apple Event forced Cocoa Scripting to walk the ~91,000-draft library via per-index Core Data fetches — 10h stuck main thread, 54GB footprint. Killing osascript does not cancel the in-app event; retries queue more scans.

Current mitigations are all imperative and fragile: two hand-run `defaults write` commands, and hand-edited files inside `~/.bun/install/global/node_modules/@agiletortoise/drafts-mcp-server/dist/` (20s osascript watchdog, global filesystem lock, bulk-tool gating behind `DRAFTS_MCP_ALLOW_BULK`, 200-result cap, NaN-date guard, exit-on-stdin-EOF). All of it dies on `bun update -g`. Two clients consume the server: Claude Code (`~/.claude.json`) and Codex (`~/.codex/config.toml`), both pointing at the mutable `~/.bun/bin` path.

## 2. Goals / non-goals

**Goals:** every mitigation declarative in this flake; survives `bun update`, reboots, OS updates; both clients point at an immutable patched binary; failures detected in minutes not days; bulk reads become possible again (SQLite path); the pattern is extractable for the next AppleScript-bridged app.

**Non-goals:** replacing AppleScript for *writes* (works fine at O(1)); managing Drafts.app installation itself (noted as an open question); building the `mkAppleEventMcp` abstraction before a second app exists — C ships the SQLite path now but only *sketches* the abstraction contour.

## 3. Architecture

Three layers, shipped in order A → B → C even within the approved full scope:

- **A — Own the artifact:** nix-built patched server + declarative defaults + declarative client registration.
- **B — Watch the seam:** health probe + failure-signature hook. Watches behavior, not implementation, so it also catches silent rot (an OS update re-enabling auto-termination).
- **C — Change the wire for reads:** SQLite read-only fast path for bulk queries; AppleScript stays for writes and workspaces.

## 4. Tier A — durable core

### 4.1 `pkgs/drafts-mcp-server.nix`

- `buildNpmPackage` from the registry tarball (fallback if `npmDepsHash` resolution misbehaves: `stdenv` + vendored `node_modules`) for `@agiletortoise/drafts-mcp-server@1.0.12`. **Verified:** the tarball's `dist/` is not self-contained — bare imports of `@modelcontextprotocol/sdk` and `commander` — so dependency resolution at build time is required; a plain copy-and-wrap fails instantly.
- Every local patch expressed as `substituteInPlace --replace-fail` (or patch files + `checkPhase` grep assertions). The patch set to carry, verbatim from the current hand-patched dist:
  1. osascript watchdog (default 20s, env `DRAFTS_MCP_OSASCRIPT_TIMEOUT_MS`)
  2. 8MB osascript output cap
  3. global filesystem lock serializing AppleScript across all server instances
  4. bulk tools (`drafts_get_drafts`, `drafts_search`, `drafts_get_tag`, `drafts_get_workspace_drafts`) hidden unless `DRAFTS_MCP_ALLOW_BULK=1`
  5. result cap (`DRAFTS_MCP_MAX_RESULTS`, default 200)
  6. NaN/ISO-date guard in `isoDateToAppleScriptDate`
  7. exit on stdin EOF/close (orphan-process fix)
  8. version string `1.0.5` → `${version}` (tripwire: build fails if the literal moves)
- Wrapper sets env defaults; `meta.mainProgram = "drafts-mcp-server"`.
- **Tripwire principle:** an upstream bump that invalidates any patch is a red `nix build`, never a silently unpatched server.

### 4.2 Defaults

`modules/darwin/defaults.nix` gains:

```nix
system.defaults.CustomUserPreferences."com.agiletortoise.Drafts-OSX" = {
  NSAppSleepDisabled = true;           # App Nap off
  NSDisableAutomaticTermination = true; # stops the SIGTERM reap loop (verified 2026-07-17)
};
```

Reasserted every `darwin-rebuild switch`. Known limit: CustomUserPreferences merges, it does not own the domain.

### 4.3 Client registration

- **Claude:** clone the existing `claudeMcpFff` activation pattern in `modules/home/claude.nix` → `claudeMcpDrafts`, registering `lib.getExe pkgs.drafts-mcp-server`, idempotent via jq-diff of `~/.claude.json`'s `.mcpServers.drafts.command`.
- **Codex:** render `[mcp_servers.drafts]` in the nix-managed codex config with the store path and the same env block (today Codex has no env at all — that is how unguarded bulk queries got through).
- **Retire the mutable copy:** `bun remove -g @agiletortoise/drafts-mcp-server` — one-time imperative step, listed in the activation notes.

### 4.4 Rollback and cutover

Keep the bun copy untouched until the store-path server passes verification (§8); rollback = re-point the two configs (one `claude mcp add`, one config line). After verification, remove the bun global and kill lingering old-code server processes. A grep in the health probe (§5.1) flags any client config that still references `~/.bun/`.

### 4.5 Upstream

File one issue to Agile Tortoise (repo per package.json; fallback: forums.getdrafts.com) containing: the 91k `whose`-scan pathology (10h/54GB, per-index Core Data fetches), the reap-loop root cause and the two defaults, and the patch set as candidate PRs (timeout, caps, gating, EOF exit, version string). One maintainer owns both app and server — this is the only path that eventually deletes the patches.

## 5. Tier B — self-healing seam

### 5.1 Health probe

Extend the existing nix-built `martin-macos-health-report` with a `Drafts MCP` section, and add a second, lighter launchd timer running just that section every 30 minutes (the daily full report alone leaves the 24h gap):

- osascript round-trip: `tell application "Drafts" to get name of workspaces` with the perl-alarm timeout (no `timeout` binary on this host); record latency.
- scan newest `~/Library/Caches/claude-cli-nodejs/*/mcp-logs-drafts/*.jsonl` for the failure taxonomy (§7) since last run.
- verify both defaults keys still read `1`; verify no client config references `~/.bun/`; count live `drafts-mcp-server` processes (alert threshold: >6).
- closes the current up-to-24h detection gap.

### 5.2 `PostToolUseFailure` hook

**Verified:** `PostToolUse` does NOT fire on failed MCP calls; `PostToolUseFailure` fires for both in-band tool errors and JSON-RPC error responses. Hook matcher `mcp__drafts__.*` maps the observed signature (§7) to an `additionalContext` retry hint (e.g. `-609` → "Drafts relaunching, retry once after 5s"; `-32000` → "server process died, session must reconnect"). **Open item carried into implementation:** confirm the hook fires on client-side transport death (`MCP error -32000`) — unverified; if it does not, the health probe is the only detector for that mode and the hook ships without that mapping.

## 6. Tier C — change the wire for reads

### 6.1 SQLite read-only fast path

**Verified on this machine:** `~/Library/Group Containers/GTFQ98J4YG.com.agiletortoise.Drafts/DraftStore.sqlite` (131MB, WAL). Schema mapped and cross-checked live against AppleScript: `ZMANAGEDDRAFT` (`ZUUID` unique-indexed, `ZFOLDER` 0=inbox/1=archive/10000=trash, `ZFLAGGED`, `ZHIDDEN=1` invisible to AppleScript, Core Data epoch offset +978307200), `ZMANAGEDDRAFTTAG` joined by `ZDRAFT_UUID` string. Pre-indexed for exactly these queries.

Design:

- Implemented as an additional derivation patch: bulk read tools (`drafts_get_drafts`, `drafts_search`, `drafts_get_tag`) route to SQLite; writes, `drafts_open*`, and workspace tools stay AppleScript (**no workspace table exists in the store** — verified).
- Snapshot protocol: APFS-clone db+wal+shm to a temp dir, open read-only, **retry-on-open-failure loop** (the three clones are not atomic against a live writer), query, delete. Never open the live files.
- Visibility contract: `WHERE ZHIDDEN = 0` always; `ZSNOOZE_UNTIL` semantics unknown (all NULL here) — exclude non-NULL future values defensively and note it.
- Self-check probe shipped alongside: one known-UUID row compared between SQL and an O(1) AppleScript `draft id` fetch; run by the health probe. Any Drafts major update is a re-verify event (folder constants are undocumented internals).
- With this path proven, `DRAFTS_MCP_ALLOW_BULK` can default on for SQLite-served tools; AppleScript bulk stays gated forever.

### 6.2 Generalization contour (sketch only, deliberately unbuilt)

`mkAppleEventMcp { name; package; bundleId; appName; env; }` emitting package + lifecycle defaults + client registrations + probe as one unit, and a `martin.mcpServers.<name>` registry feeding claude/codex renderers. Build it when the second app (OmniFocus/Bear/Things) arrives; today it would be an N=1 abstraction.

## 7. Failure taxonomy (verified from outage logs)

| Signature | Meaning | Latency | Response |
|---|---|---|---|
| `Drafts got an error: Connection is invalid. (-609)` | app died mid-event | ~1s | retry once after relaunch delay |
| `AppleScript execution failed: unknown error` | osascript died, empty stderr | ~25s | app mid-reap; retry once |
| `AppleScript timed out after Nms` | watchdog fired | 20s | do not retry bulk; check app state |
| `MCP error -32000: Connection closed` | server process died | any | reconnect session; health probe territory |
| `The variable NaN is not defined. (-2753)` | pre-guard date bug | 0s | fixed by patch 6; appearance = tripwire failure |

## 8. Verification plan

1. `nix build .#drafts-mcp-server` green; run binary directly: stdio handshake returns patched version string.
2. Tripwire test: sabotage one anchor string in a vendored copy → build must fail.
3. `darwin-rebuild switch` → `defaults read` shows both keys; `~/.claude.json` and codex config show store paths.
4. Kill-test: quit Drafts, call a tool → relaunch + success; verify `-609`/timeout mapping fires the hook.
5. Transport-death test: kill the server mid-session → does `PostToolUseFailure` fire? (decides §5.2 open item).
6. SQLite parity: 20-draft sample, SQL vs AppleScript field-for-field; snapshot retry loop exercised under a write loop (create drafts in a spin).
7. Rollback drill: repoint one client back to the bun copy and forward again.
8. Soak: health probe green for 48h, zero orphan processes.

## 9. Risks and open questions

- `buildNpmPackage` never actually run yet — keystone assumption; first implementation step.
- CustomUserPreferences cannot delete retired keys (imperative residue if we ever back out).
- SQLite internals undocumented; Drafts major update may shift constants (mitigated by self-check probe + re-verify rule).
- Drafts.app itself remains unmanaged (no declarative install/version pin; auto-update uncontrolled). Open question, deliberately out of scope.
- `~/.claude.json` is CLI-managed mixed state; registration touches only `.mcpServers.drafts` and only via the `claude mcp` CLI.

## 10. Sequencing

A1 derivation → A2 defaults → A3 registration (claude, codex) → §8.1–3 verify → A4 cutover → A5 upstream issue → B1 probe → B2 hook (+ §8.5 decides its scope) → C1 SQLite patch → §8.6 parity → C1 enable bulk → C2 stays a sketch.
