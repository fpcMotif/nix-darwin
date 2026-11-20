---
name: nix-config-land-autoupdate-main
description: PR creation, review, and landing onto main in nix-config via single-flight jj pr.
---

# Land PR and local work onto main

Deterministic procedure for landing local changes, auto-update commits, and PR branches onto `main`.

## 1. Verification gate

Run required checks before landing:
```sh
just check
just verify-skills    # only when agent-skill files changed
```
- **Rolling pin drift**: if fixed-output hash mismatches occur on Bun or SF Mono pins, run `just refresh-rolling`, commit the updated pin, and re-verify.

## 2. Single-flight landing

Execute the entire commit → PR → merge → sync pipeline in one command:

```sh
# Builds the checkout's jj pr, so it works before a rebuild
nix run .#martin.jj-pr -- <name> -m "type(scope): msg" -t "PR title" -F /path/to/body.md --land

# Same flight through the installed alias, after darwin-rebuild switch
jj pr <name> -m "type(scope): msg" -t "PR title" -F /path/to/body.md --land
```

Run `jj pr --help` before the second form. An installed `jj pr` that predates this repo's `jj-pr.sh` lacks `-m` and `--land`.

If integrating conflicting branches locally before pushing:
```sh
jj new main <feature-branch> @ -m "merge: land <feature> onto main"
jj resolve --list
jj bookmark move main --to @ --allow-backwards
jj git push --bookmark main
jj new main
```

## 3. Completion criteria

- `jj status` reports clean working copy `@` on top of `main`.
- `jj diff --from main --to <feature-branch>` returns empty (zero drift).
- Remote `main` matches local `main`.
