# Workspace backends: Worktrunk and experimental dojjo

## At a glance

Worktrunk (`wt`) was enabled unconditionally, and it only manages Git worktrees, which JJ never sees.
One Home Manager option, `martin.development.workspaceBackend`, now chooses between Worktrunk and experimental dojjo (`djo`), which manages JJ workspaces.
The default stays `worktrunk`, and switching never converts, migrates, or deletes a repository, workspace, worktree, or approval.

## The choice

| Setting | Installs | Owns | Creates |
| --- | --- | --- | --- |
| `worktrunk` (default) | `wt` | `~/.config/worktrunk/config.toml` | Git worktrees |
| `dojjo` (experimental) | `djo` (pinned 0.2.2, aarch64-darwin) | `~/.config/dojjo/config.toml` | JJ workspaces |

Select it in the host's Home Manager user, then switch:

```nix
home-manager.users.martinfan.martin.development.workspaceBackend = "dojjo";
```

Inspect the evaluated choice:

```bash
nix eval .#darwinConfigurations.f.config.home-manager.users.martinfan.martin.development.workspaceBackend
```

The option also selects the Zsh integration, the "Parallel checkouts" section of every agent's development guide, and the Claude Worktrunk activity hooks.
JJ and Git configuration stay independent of it, so Git interoperability keeps working under dojjo.
Selecting `dojjo` on any platform other than aarch64-darwin fails evaluation with a message naming the supported platform.

## Three commands, kept distinct

- `jj` is the version-control system. dojjo calls it for every operation: `jj workspace add`, `jj workspace forget`, `jj bookmark`, `jj squash`, and `jj rebase`.
- `djo` adds Worktrunk's workflow on top: sibling paths, `cd` on switch, lifecycle hooks, and a bookmark per workspace.
- `wt` manages Git worktrees. A Git worktree is invisible to JJ, even in a colocated repository.

No alias maps one onto another, because their semantics differ.
For example, `wt remove` refuses uncommitted changes, while `djo remove` abandons the revision and deletes the directory after one confirmation.

## Native commands under dojjo

| Task | Command |
| --- | --- |
| Create | `djo switch --create NAME --base REV` |
| Switch | `djo switch NAME` (the Zsh wrapper changes directory) |
| List | `djo list` |
| Clean up | `jj status` in the workspace, then `jj workspace forget NAME`, then delete the directory |

`djo switch --create` bases the workspace on `trunk()` by default.
In a repository without a remote trunk bookmark, `trunk()` is the empty root commit, and the new workspace is empty.

Cleanup uses jj directly on purpose.
`jj workspace forget` keeps the change, its bookmark, and every file on disk.
jj snapshots only the workspace a command runs in, so `jj status` inside the workspace records its edits first.

## Configuration

dojjo merges these files, lowest precedence first:

1. `~/.config/worktrunk/config.toml` (absent under this backend)
2. `.config/wt.toml` in the project
3. `~/.config/dojjo/config.toml` (Nix-owned)
4. `dojjo.toml` in the project
5. `dojjo.local.toml` in the project

The Nix-owned file declares every key dojjo needs, instead of relying on Worktrunk's `worktree-path` fallback:

```toml
workspace-path = "{{ repo_path }}/../{{ repo }}.{{ branch | sanitize }}"

[merge]
push = false
remove = false
```

Because the Nix-owned file outranks `.config/wt.toml`, a project's `worktree-path` does not move dojjo workspaces.
dojjo renders `repo_path` from the workspace it runs in, not from the default workspace.
Creating a workspace from a secondary workspace therefore nests the name, as in `repo.a.b`.

Unknown keys are ignored without a warning.
The global Worktrunk keys `commit.generation.command`, `list.json-schema`, and `skip-shell-integration-prompt` have no dojjo meaning.
They are also absent under this backend, since Home Manager removes Worktrunk's `config.toml`.

## Hooks and trust

dojjo runs hooks from `.config/wt.toml` and `dojjo.toml`, appending one list to the other.
It rewrites `wt step NAME` to `djo run NAME`, and any other `wt ` command to `djo `.
That rewrite is a word match, so it also rewrites `wt` inside unrelated command text.

Worktrunk asks before running a project hook and records approvals in `~/.config/worktrunk/approvals.toml`.
dojjo 0.2.2 has no approval step: it runs project hooks as soon as a command reaches them.
Treat `djo` in an untrusted repository like running its setup script.
Switching backends leaves `approvals.toml` untouched, so rollback restores Worktrunk's trust state.

A project with hooks in both files runs both sets.
`ignore-worktrunk-hooks = true` in `dojjo.toml` keeps only the dojjo set.
The Nix-owned files define no hooks, so user configuration never duplicates project hooks.
Pre-hooks block, and a failing pre-hook stops the command with its exit code.
Post-hooks log to `.jj/djo/logs`.

## Destructive dojjo commands

- `djo remove` forgets the workspace, deletes its bookmark, abandons its revision, and deletes the directory. It asks once; `-y` skips the question.
- `djo merge` squashes, rebases, and moves the target bookmark. The Nix config keeps the directory and never pushes.
- `djo prune` removes every workspace whose bookmark reached `trunk()`.

`djo merge` needs committed work.
When both the working copy and its parent carry descriptions, `jj squash` asks for an editor.
djo gives jj no terminal, so the merge hangs, or fails if the editor exits.
The failure message suggests `jj op undo`.

`djo merge` also fails to forget the workspace it merged.
It runs `jj workspace forget @`, and jj 0.45 reads `@` as a workspace name:

```text
Warning: No such workspace: "@"
Nothing changed.
```

jj exits 0, so the merge reports success while the workspace stays registered.
Upstream's default `merge.remove = true` would then delete the directory of a registered workspace.
The Nix config sets `merge.remove = false`, which leaves both in place for `jj workspace forget NAME`.
Its confirmation banner still says "delete", because the text ignores that setting.

## Claude Code

Under Worktrunk, Claude hooks mark activity per branch in `wt list`.
Under dojjo, activation removes exactly those six hook entries from `~/.claude/settings.json`.
It matches event, matcher, and full command, so user hooks in the same events and groups remain.
Switching back adds them again. dojjo gets no replacement marker.

Claude Code's built-in worktree feature is unchanged and still creates Git worktrees.
It sits outside the JJ workspace workflow, and the dojjo guidance tells agents not to use it in a `.jj` repository.

## Rollback

Set the option back to `worktrunk` and switch.
Home Manager restores `wt`, its config, its Zsh wrapper, and the Claude hooks.
JJ workspaces remain on disk and registered; `jj workspace list` still shows them.

## Evidence

- `unit-workspace-backend-lifecycle` drives both tools in disposable Git, JJ-only, and colocated repositories. It uses the config files and Zsh lines each backend ships.
- The same test runs every dojjo claim above against the pinned binary. That covers precedence, ignored keys, hook rewriting, missing approval, and both merge defects.
- `unit-claude-settings-ownership` runs Worktrunk, then dojjo, then Worktrunk against a temporary home, and checks hooks and approvals.
- `integration-configurations-eval` evaluates host `f` under both backends and checks the Linux assertion.
- `unit-agent-guides` checks that each backend's guide names only its own commands.
