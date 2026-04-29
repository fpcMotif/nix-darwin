# Agent Skills Nix Report

## Executive summary

This repo now uses `agent-skills-nix` through its upstream Home Manager module in `modules/home/skills.nix`. That is the right long-term direction: Nix builds one selected skill bundle, while Home Manager activates that bundle into the directories that Codex, Claude Code, Cursor, and Oh My Pi actually scan.

The remaining target mapping is intentional. AI agents are not Nix-aware; they discover skills by reading specific filesystem locations such as `$HOME/.agents/skills`, `~/.claude/skills`, or `~/.cursor/skills`. Nix can build the skill tree in `/nix/store`, but some bridge still has to expose that immutable store tree at those runtime paths.

There is a more "Nix-native" path, but it is not a full replacement for the current mapping:

- `home.file` is the most native Home Manager symlink mechanism for static paths.
- `agent-skills-nix` already supports that as `structure = "link"`.
- For these skill targets, `symlink-tree` is usually safer because it creates a writable target directory and symlinks/copies the bundle contents into it during activation.
- Fully pure Nix store paths or Nix profiles alone are insufficient because the agents do not scan arbitrary Nix store/profile locations.

Recommendation: keep `programs.agent-skills` plus `symlink-tree` global targets. Use `link` only for static, fully Nix-owned paths where the agent never needs to create runtime files inside the skill root.

## Current implementation

Live file: `modules/home/skills.nix`.

The module imports:

```nix
inputs.agent-skills.homeManagerModules.default
```

and configures:

```nix
programs.agent-skills = {
  enable = true;

  sources = {
    dotfiles-pi = filteredSource "dotfiles" "dot_pi/agent/skills"
      "^(git-workflow|review|ralph-loop|web-browser)$";

    dotfiles-claude = filteredSource "dotfiles" "dot_claude/skills"
      "^(lazygit)$";

    grill-me = rootSkillSource "mattpocock-skills" "grill-me";
  };

  skills = {
    enable = [ ];
    enableAll = false;
    explicit = {
      git-workflow = {
        from = "dotfiles-pi";
        path = "git-workflow";
        packages = [ pkgs.git pkgs.gh pkgs.jq ];
      };
      review = {
        from = "dotfiles-pi";
        path = "review";
        packages = [ pkgs.git pkgs.gh pkgs.jq ];
      };
      lazygit = {
        from = "dotfiles-claude";
        path = "lazygit";
        packages = [ pkgs.git pkgs.lazygit ];
      };
      ralph-loop = { from = "dotfiles-pi"; path = "ralph-loop"; packages = [ ]; };
      web-browser = { from = "dotfiles-pi"; path = "web-browser"; packages = [ ]; };
      grill-me = { from = "grill-me"; path = "."; packages = [ ]; };
    };
  };

  targets = {
    agents.enable = true;
    claude.enable = true;
    cursor.enable = true;
    codex.enable = true;

    pi = {
      enable = true;
      dest = "$HOME/.pi/agent/skills";
      structure = "symlink-tree";
      systems = [ ];
    };
  };
};
```

## Current target mapping

| Target | Destination | Why it exists |
| --- | --- | --- |
| `agents` | `$HOME/.agents/skills` | Shared Open Agent Skills registry. Codex documents this as a user-level skills path. Cursor also documents it as a user-level skills path. |
| `claude` | `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills` | Claude Code documents personal skills under `~/.claude/skills`. |
| `cursor` | `$HOME/.cursor/skills` | Cursor documents this as its native user-level skills path. |
| `codex` | `${CODEX_HOME:-$HOME/.codex}/skills` | Compatibility mirror provided by `agent-skills-nix`. Codex's primary documented path is `$HOME/.agents/skills`, so this can be removed later if duplicate discovery is a concern. |
| `pi` | `$HOME/.pi/agent/skills` | Oh My Pi / Pi harness-specific skill location. This is custom and not part of upstream `agent-skills-nix` defaults. |

## Why mapping still exists

The mapping exists because three separate systems have different responsibilities:

1. **Nix evaluation/build time**
   - Discovers skill sources.
   - Selects allowlisted skill IDs.
   - Builds one immutable bundle in `/nix/store`.

2. **Home Manager activation time**
   - Places that bundle where user-space applications expect it.
   - Handles `$HOME`, `${CLAUDE_CONFIG_DIR:-...}`, `${CODEX_HOME:-...}`, and custom paths.
   - Can create writable destination directories for runtime-managed files.

3. **Agent runtime**
   - Scans fixed paths.
   - Does not know about Nix flake outputs or store bundles unless those are exposed at its expected path.

So the target mapping is not accidental duplication; it is the boundary between Nix's immutable store and each agent's runtime discovery convention.

## Is there a Nix-native way?

### Short answer

Partially. Home Manager's `home.file` is the Nix-native way to link files into `$HOME`, and `agent-skills-nix` exposes it as `structure = "link"`. But `link` is not universally suitable for skill directories.

### Option comparison

| Option | Nix-native? | Works with env-expanded destinations? | Target writable? | Best use |
| --- | --- | --- | --- | --- |
| `home.file` / `structure = "link"` | Yes | No, static paths only | Usually no; points at `/nix/store` | Static, fully Nix-owned, read-only targets. |
| `home.file.recursive = true` | Yes | No, static paths only | Target dirs exist, leaves are symlinks | Static directory trees where Home Manager owns all files. |
| `symlink-tree` activation | Home Manager-native activation, not pure option-only linking | Yes | Yes, destination dir can be writable | Best global skills default. |
| `copy-tree` activation | Home Manager-native activation, not pure option-only linking | Yes | Yes | Best project-local installs where files should be inspectable/editable. |
| Nix profile package | Yes | Not applicable | Not at agent path | Not enough; agents do not scan profile package resources. |
| `/etc/codex/skills` via system config | Yes for Codex admin scope | Static system path | System-owned | Codex-only; not universal and requires admin/system ownership. |

### Why `link` is not the default here

`agent-skills-nix`'s Home Manager module explicitly treats `link` differently: it uses `home.file`, and comments note that `link` requires a static path relative to `$HOME`; shell-variable expansion is not supported for `link`. The default agent targets include env-expanded paths such as `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills` and `${CODEX_HOME:-$HOME/.codex}/skills`, so `symlink-tree` is the safer default.

`symlink-tree` also keeps the destination directory writable. That matters because `agent-skills-nix` excludes the root-level `/.system` path by default so agents can manage their own runtime/system skill state without Nix deleting or replacing it.

## What `agent-skills-nix` already does well

From the upstream reference repo:

- Discovers directories containing `SKILL.md`.
- Supports nested skill IDs using `/` separators.
- Supports `idPrefix` to avoid duplicate IDs across sources.
- Supports source filters with `filter.maxDepth` and `filter.nameRegex`.
- Supports explicit allowlists with `skills.enable`.
- Supports trusted-source bulk enablement with `skills.enableAll`.
- Builds a single selected bundle via `mkBundle`.
- Supports global targets and local project targets.
- Supports three structures: `link`, `symlink-tree`, and `copy-tree`.
- Supports package injection plus `SKILL.md` transforms for skills that need Nix-provided tools.
- Defaults to `excludePatterns = [ "/.system" ]` so agents can keep their own runtime-managed subtree.

The live repo should keep using the Home Manager DSL instead of re-implementing these pieces locally.

## Universal target policy

Recommended policy for this repo:

1. Keep `$HOME/.agents/skills` enabled as the shared default.
2. Keep `~/.claude/skills` enabled because Claude Code documents it as the personal skills path.
3. Keep `~/.cursor/skills` enabled if Cursor is actively used; Cursor also sees `$HOME/.agents/skills`, but the native mirror makes debugging easier.
4. Treat `${CODEX_HOME:-$HOME/.codex}/skills` as optional. Codex documents `$HOME/.agents/skills`; the Codex-specific mirror is useful only for compatibility with tools or habits that expect `.codex/skills`.
5. Keep `$HOME/.pi/agent/skills` enabled for Oh My Pi while that harness expects it.
6. Do not add Zed or VS Code skill targets yet. Zed currently documents rules files, and Agent Skills support is still visible as an open PR. VS Code Copilot documents instructions and `AGENTS.md`, not `SKILL.md` directories.

## Future revision checklist

When revising this setup:

1. Add new skill sources as flake inputs.
2. Register the source under `programs.agent-skills.sources`.
3. Prefer `skills.explicit.<name>` when a skill needs Nix-provided packages/metadata/renaming; otherwise `skills.enable = [ ... ]` is acceptable. Avoid `enableAll` for public third-party sources.
4. Use `idPrefix` before enabling two sources with overlapping skill IDs.
5. Keep `filter.maxDepth = 1` only for intentionally flat curated source roots; otherwise prefer recursive discovery.
6. Enable only targets that correspond to tools actually used.
7. Before enabling a new target, check whether that directory already contains unmanaged files. Activation can delete or overwrite files depending on the selected structure.
8. If a skill needs tools such as `jq`, `curl`, or language runtimes, use `skills.explicit.<name>.packages` and/or `transform` so the dependency is declared in Nix and visible from the skill directory.
9. Run `nix fmt ./` and `darwin-rebuild build --flake .#Martins-Mac-mini` on a Nix-capable machine.

## Grill-me review

### Why not just point every agent at one directory?

Because not every agent documents the same directory. `$HOME/.agents/skills` is the best shared target, but Claude Code documents `~/.claude/skills`, Cursor documents both shared and Cursor-specific paths, and Oh My Pi uses its own path.

### Why not put the bundle only in `/nix/store`?

Because agents scan their documented skill directories. A Nix store bundle is invisible unless the agent is explicitly taught to scan it, which these tools do not generally support.

### Why not use only `home.file`?

Use it where possible, but not universally. `home.file` is static and symlink-based. It does not expand runtime shell variables in target paths and is awkward when the target directory must remain writable for runtime-managed files.

### Why keep `symlink-tree` if it still makes symlinks?

Because it is the right boundary: Nix owns the immutable skill contents, while Home Manager creates a writable destination directory that agents can scan. The symlink leaves keep content deduplicated and store-backed without making the whole target path a read-only store symlink.

### What should be simplified later?

If duplicate discovery becomes noisy, first remove `targets.codex.enable = true` and rely on `$HOME/.agents/skills` for Codex. Do not remove `targets.claude` unless Claude Code begins documenting `$HOME/.agents/skills` as a supported personal skills path.

## References

- Agent Skills specification: <https://agentskills.io/specification>
- `agent-skills-nix` default target paths: <https://github.com/Kyure-A/agent-skills-nix#default-target-paths>
- `agent-skills-nix` Home Manager module and DSL: <https://github.com/Kyure-A/agent-skills-nix#quick-start-child-flake--home-manager>
- Codex Agent Skills locations: <https://developers.openai.com/codex/skills#where-to-save-skills>
- Claude Code skills locations: <https://code.claude.com/docs/en/skills#where-skills-live>
- Cursor skill directories: <https://cursor.com/docs/skills#skill-directories>
- Zed current rules-file behavior: <https://zed.dev/docs/ai/rules#rules-files>
- Zed Agent Skills PR to revisit later: <https://github.com/zed-industries/zed/pull/50453>
- VS Code Copilot custom instructions: <https://code.visualstudio.com/docs/copilot/customization/custom-instructions>
- Home Manager `home.activation`: <https://home-manager.dev/manual/24.11/options.xhtml#opt-home.activation>
- Home Manager `home.file`: <https://home-manager.dev/manual/24.11/options.xhtml#opt-home.file>
- Home Manager `home.file.recursive`: <https://home-manager.dev/manual/24.11/options.xhtml#opt-home.file._name_.recursive>

## Verification status

Verified in this environment:

- `modules/home/skills.nix` now uses the upstream Home Manager DSL.
- No old `home.activation.agentSkills*`, direct `mkSyncScript`, or direct `inputs.agent-skills.lib.agent-skills` code remains in the live skills module.
- `git diff --check` passed after the implementation change.

Not verified here:

- `nix fmt ./`
- `nix eval`
- `darwin-rebuild build --flake .#Martins-Mac-mini`

Reason: this Windows environment does not have `nix`, `nixpkgs-fmt`, or `nixfmt` available, and WSL is unavailable/misconfigured.
