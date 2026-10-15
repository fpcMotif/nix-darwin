---
name: nix-config-land-autoupdate-main
description: PR creation, review, and landing onto main in nix-config via single-flight jj pr or jj-ship.
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
# Single-flight CLI
jj pr <name> -m "type(scope): msg" -t "PR title" -F /path/to/body.md --land

# Programmatic Code Mode alternative
bun run scripts/jj-ship.ts -n <name> -m "type(scope): msg" -t "PR title" -F /path/to/body.md --land
```

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
