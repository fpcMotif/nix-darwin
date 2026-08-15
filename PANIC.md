# PANIC: rolling back an auto-update gone wrong

The `.github/workflows/auto-update.yml` opens a PR every day and auto-merges
it once `build.yml` is green. CI catches build-time regressions but not
runtime ones (a bumped binary may build fine and crash on first invocation).
This doc is the panic button for that case.

## 1. Pin one input back to a known-good version, no rebuild needed

Fastest mitigation. Targets a single misbehaving input without reverting other
bumps that landed in the same PR.

```bash
sudo nix run nix-darwin -- switch \
  --flake "$HOME/nix-config#f" \
  --override-input claude-code github:sadjow/claude-code-nix?ref=v2.1.121
```

Substitute the input name (`claude-code`, `nixpkgs`, etc.) and a tag/ref you
trust. The override sticks for that single rebuild only — it does not touch
`flake.lock`, so a subsequent `nix flake update` will re-introduce the new
version.

To make the pin survive across rebuilds, edit `flake.nix` to add the `?ref=…`
back and commit.

## 2. Revert the most recent auto-merged PR

Reverses every bump in the last nightly. Use when you cannot tell which agent
broke and want a fast restore.

```bash
gh pr list --label auto-update --state merged --limit 1 \
  --json number -q '.[0].number' \
  | xargs -I {} gh pr revert {}
```

Then `git pull` on `main` and rebuild.

## 3. Stop the workflow

Renaming disables the workflow without deleting it.

```bash
git mv .github/workflows/auto-update.yml \
       .github/workflows/auto-update.yml.disabled
git commit -m "chore: pause auto-update"
git push
```

Re-enable by reverting the rename.

## 4. Recompute a stale Cachix substitution

If `claude-code.cachix.org` serves a corrupted derivation, override the
substituter for one rebuild:

```bash
sudo nix run nix-darwin -- switch \
  --flake "$HOME/nix-config#f" \
  --option substituters https://cache.nixos.org \
  --option trusted-public-keys 'cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY='
```

Then file an issue at <https://github.com/sadjow/claude-code-nix/issues>.

## 5. A cache you already removed still 502s every switch (stale /etc/nix/nix.conf)

Symptom: every `just switch` dies with
`error: unable to download 'https://<old-cache>/....narinfo': HTTP error 502`
even though `modules/darwin/nix.nix` no longer lists that cache.

Cause: `/etc/nix/nix.conf` is written at activation time, so until a switch
succeeds it still contains the *previous* generation's substituter list.
`just switch` runs plain `sudo darwin-rebuild`, and sudo strips the
`NIX_CONFIG` that `.envrc` exports, so root's nix reads the stale file. Nix
treats a narinfo 502 as fatal (unlike a 404, which just means "not cached"),
so the build dies before activation can rewrite nix.conf — chicken-and-egg.

Break the cycle with a one-shot substituter override (an escape hatch for one
run, not something to bake into the justfile):

```bash
sudo darwin-rebuild switch --flake . --fallback \
  --option substituters 'https://cache.nixos.org https://claude-code.cachix.org' \
  --option trusted-public-keys 'cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk='
```

Activation regenerates `/etc/nix/nix.conf` from the current configuration.
Verify afterwards:

```bash
grep '^substituters' /etc/nix/nix.conf
```

The source side is guarded by the `darwin-nix-substituters-exclude-garnix`
unit test (tests/unit/mksystem-test.nix); this section is the live-system
counterpart.

## 6. Every nix command dies with "cannot connect to socket" (daemon booted out)

Symptom: `just switch`, `nix build`, even direnv's `nix print-dev-env` all fail
instantly with

```
error: cannot connect to socket at '/nix/var/nix/daemon-socket/socket': Connection refused
```

Cause: macOS Background Task Management removed `org.nixos.nix-daemon` from
launchd. Confirm it — the tell is that launchd does not know the label at all,
not that the daemon crashed:

```bash
/usr/bin/log show --last 1d --predicate 'eventMessage CONTAINS "org.nixos.nix-daemon"' --style compact | rg 'removing service|Could not find job'
```

`removing service: org.nixos.nix-daemon` right after a
`backgroundtaskmanagementd … getItemWithIdentifier` line is BTM disabling it.
The `.plist` in `/Library/LaunchDaemons` and the nix binary it points at are
both untouched, and the socket *file* survives — only the job is gone, so
`ls -S` on the socket proves nothing. BTM walks the whole list at once, so
`nix-gc`, `nix-optimise`, `activate-system` and `nix-auto-switch` usually go
with it.

Every nix launch item registers as a generic `sh` (the plists exec
`/bin/sh -c 'wait4path /nix/store && exec …'`), which is exactly what makes it
an easy accidental toggle-off in Login Items — and what a third-party cleaner
utility prunes when it "tidies" background items.

Repair:

```bash
just fix-daemon
```

That is the `_daemon` preflight, which every build/switch recipe runs first: it
connects to the socket and, only if that fails, re-enables and re-bootstraps
the job.

### If it comes back at every boot

`just fix-daemon` only restores the job for the current boot. When the daemon
is gone again after *every* restart, BTM is not removing the item — it is
holding a stored `disallowed` approval for it. Read the disposition:

```bash
/usr/bin/log show --last 1d --predicate 'subsystem == "com.apple.backgroundtaskmanagement"' --style compact | rg 'registerLaunchItem: found existing item.*org\.nixos'
```

`disposition=[enabled, disallowed, notified]` is the durable block: launchd is
willing (`launchctl print-disabled system` still says `enabled`, which is a
*different* database and why that check misleads), but BTM refuses to load the
item at boot. It applies per item, so `nix-gc`, `nix-optimise`,
`activate-system` and `nix-auto-switch` are usually disallowed alongside it.

Only the GUI clears that flag: System Settings > General > Login Items &
Extensions > Allow in the Background — re-enable the entries whose path is
`/Library/LaunchDaemons/org.nixos.*.plist` (they show up as `sh`, plus
`martin-auto-switch`). Nothing in this repo can flip it; the approval database
is SIP-protected and takes no scripted writes.

Last resort, if BTM's record is corrupt rather than merely off — this wipes
every background-item approval on the machine and makes each app re-ask:

```bash
sudo sfltool resetbtm
```

### Do not probe the socket with `nc -z`

The stale socket file survives the daemon, so `_daemon` has to test by
connecting. It must use `nc -U -w 2 <socket> </dev/null`, never `nc -zU`: on
macOS `-z` is TCP/UDP scan mode and is a silent no-op against a `-U` socket, so
`nc -zU` exits non-zero even against a perfectly healthy daemon. That bug made
`_daemon` demand a sudo password on every single build and then always report
"still down after bootstrap" — including on runs where the bootstrap had in
fact succeeded. `tests/unit/justfile-test.sh` now fails the build if the
pattern reappears.

## 7. Manual updater debugging

Each agent has its own `scripts/update-*.sh`. Run it locally to reproduce the
failure shown in the workflow log:

```bash
bash scripts/update-droid.sh   # or whichever bumper failed
```

The scripts bail loudly on parser anomalies; the error message names the
expected pattern and the input that didn't match.

## 8. `switch` dies with "hash mismatch in fixed-output derivation"

Symptom: a switch that worked yesterday fails on a package you did not touch,
followed by a cascade of `Cannot build` lines for everything downstream of it:

```
error: hash mismatch in fixed-output derivation '/nix/store/…-bun-darwin-aarch64.zip.drv':
         specified: sha256-BDtiIIVVMgpx1IIj0rHevHn8aS6OtkLJrhvWSUW2bCI=
            got:    sha256-FNlizVvP0TwsBBKY0ITEuJdvUd1aeJysxpSHf5I8KeA=
error: Cannot build '…-home-manager-path.drv'. Reason: 1 dependency failed.
…
error: Cannot build '…-darwin-system-…drv'. Reason: 1 dependency failed.
```

Only the *first* error matters — everything after it is fallout from that one
derivation, so read the top of the output, not the bottom.

Cause: a **rolling pin**. A few packages are pinned to a URL that carries no
version, and upstream republishes different bytes at the same address:

| package | rolling URL |
|---|---|
| `pkgs/bun-canary-bin.nix` | bun force-pushes the `canary` tag in place |
| `pkgs/sf-mono.nix` | Apple's `SF-Mono.dmg` |
| `pkgs/google-drive.nix` | Google's `GoogleDrive.dmg` |

When upstream republishes, the recorded sha256 is stale and the fixed-output
derivation fails — and because these sit under `home-manager-path`, the stale
hash takes down the **entire system build**, not just that one package.

Repair:

```bash
just refresh-rolling
```

That re-prefetches every rolling URL and rewrites the hashes that actually
moved (the updaters are hash-driven and no-op when the bytes are unchanged).
Then re-run `just switch`.

`tests/unit/rolling-pins-test.sh` fails the build if a package is pinned to an
unversioned URL without a hash-driven `scripts/update-*.sh` behind it — a
rolling pin with no updater can only be recovered by hand-editing a hash out of
an error message, which is how this bites in the first place.

A mismatch on a pin whose URL *does* carry a version is a different and more
serious thing: that asset should have been immutable, so treat it as a possible
integrity problem rather than routine drift, and check upstream before
accepting the new bytes.
