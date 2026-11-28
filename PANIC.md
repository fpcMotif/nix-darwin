# PANIC: recovering a broken build or switch

For a bad activation that built cleanly, roll back with `sudo darwin-rebuild --rollback` or `sudo darwin-rebuild --switch-generation <N>`. To pin one flake input for a single switch, pass `--override-input <name> <url>`.

## 1. A removed binary cache still 502s every switch (stale `/etc/nix/nix.conf`)

Symptom: `just switch` fails with `HTTP error 502` on a `.narinfo` download even though `modules/darwin/nix.nix` no longer lists that cache.

Cause: Activation writes `/etc/nix/nix.conf`, so until a switch succeeds the file keeps the previous generation's substituter list. `sudo darwin-rebuild` strips `NIX_CONFIG` from `.envrc`, so root's Nix reads the stale file and aborts on the 502 before activation can rewrite `/etc/nix/nix.conf`.

Override the substituters for one switch so activation regenerates `/etc/nix/nix.conf`:

```bash
sudo darwin-rebuild switch --flake . --fallback \
  --option substituters 'https://cache.nixos.org https://claude-code.cachix.org' \
  --option trusted-public-keys 'cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk='
```

## 2. Every Nix command fails with "cannot connect to socket" (daemon booted out)

Symptom: `just switch`, `nix build`, and direnv's `nix print-dev-env` fail immediately with:

```text
error: cannot connect to socket at '/nix/var/nix/daemon-socket/socket': Connection refused
```

Cause: macOS Background Task Management removed `org.nixos.nix-daemon` (and usually `nix-gc`, `nix-optimise`, `activate-system`, and `nix-auto-switch`) from launchd. The `.plist` in `/Library/LaunchDaemons` and the socket file remain on disk, so `ls -S` on the socket does not detect it. Confirm in the unified log:

```bash
/usr/bin/log show --last 1d --predicate 'eventMessage CONTAINS "org.nixos.nix-daemon"' --style compact | rg 'removing service|Could not find job'
```

Repair for the current boot:

```bash
just fix-daemon
```

### If the daemon is gone again after every reboot

When BTM holds a stored `disallowed` approval, `launchctl print-disabled system` still reports `enabled`, while BTM refuses to load the item at boot:

```bash
/usr/bin/log show --last 1d --predicate 'subsystem == "com.apple.backgroundtaskmanagement"' --style compact | rg 'registerLaunchItem: found existing item.*org\.nixos'
```

If the log shows `disposition=[enabled, disallowed, notified]`, re-enable the `/Library/LaunchDaemons/org.nixos.*.plist` entries (listed as `sh`, plus `martin-auto-switch`) in **System Settings > General > Login Items & Extensions > Allow in the Background**. The BTM database is SIP-protected and takes no scripted writes. If BTM's database is corrupt rather than toggled off, reset all background-item approvals with `sudo sfltool resetbtm`.

## 3. `switch` fails with "hash mismatch in fixed-output derivation"

Symptom: a switch fails on an untouched package (such as `SF-Mono.dmg`), followed by `Cannot build` lines for downstream derivations. Read the first error at the top of the output.

Cause: a **rolling pin** (`pkgs/sf-mono.nix`) points to an unversioned upstream URL whose bytes changed in place. Because it sits under `home-manager-path`, the stale sha256 fails the whole system build.

Re-prefetch all rolling URLs and rewrite the moved hashes, then re-run `just switch`:

```bash
just refresh-rolling
```

A hash mismatch on a **release pin** whose URL carries a version is not routine drift; verify the upstream release before accepting new bytes.
