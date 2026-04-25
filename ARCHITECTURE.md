# Nix-darwin Architecture

> Why this Mac is set up the way it is, and how to evaluate alternatives.

## TL;DR

Three layers, each owning what it's best at:

| Layer | Tool | Owns |
|-------|------|------|
| **System** | nix-darwin (`flake.nix`) | macOS defaults, services, system apps (Dropbox, Raycast, Google Drive), Homebrew bridge |
| **User packages** | home-manager (`home.nix`) | Per-user CLI binaries (`bat`, `fd`, `rg`, `eza`, `gemini`, `codex`, …) |
| **Config files** | chezmoi (`~/dotfiles`) | Mutable text — zsh `rc.d/`, `starship.toml`, ghostty, `~/.claude`, `~/.pi` |

Activation: `sudo darwin-rebuild switch --flake ~/.config/nix-darwin#Martins-Mac-mini` rebuilds layers 1 and 2 atomically. `chezmoi apply` syncs layer 3.

## The Problem We Were Solving

The dotfiles repo aliased ~20 modern CLI tools (`eza`, `bat`, `fd`, `rg`, `dust`, `procs`, `btm`, `zoxide`, `fzf`, `lazygit`, `delta`, `ast-grep`, `mgrep`, `starship`, `sheldon`, …) but **none of them were installed via Nix**. They were drifting in from `/opt/zerobrew`, ad-hoc Homebrew installs, or simply absent. That's the literal sense in which "dotfiles weren't fit for the Nix system": configs that *expected* a curated tool surface, on a machine where the tool surface was unmanaged.

We did not have a config-file problem. The `rc.d/` modular layout, sheldon plugin set, and starship theme are good as-is — rewriting them as Nix string literals (`programs.zsh.initContent = ''…''`) buys nothing and loses readability.

## The Solution: Hybrid Three-Layer Split

```
┌─────────────────────────────────────────────────────────────┐
│ flake.nix              system layer                         │
│   • nix-darwin module  : macOS settings, services           │
│   • nix-homebrew       : managed brew casks (windsurf@next) │
│   • home-manager       : pulls in user layer                │
│   • environment.systemPackages = [ dropbox, gdrive, raycast]│
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│ home.nix               user layer (per-martinfan)           │
│   • home.packages = [ bat fd ripgrep eza … gemini codex ]   │
│   • NO programs.zsh / programs.starship enable             │
│     (would clobber chezmoi-managed files)                   │
└────────────────────────┬────────────────────────────────────┘
                         │ binaries land in ~/.nix-profile/bin
                         │ (referenced by configs below)
┌────────────────────────▼────────────────────────────────────┐
│ ~/dotfiles             config layer (chezmoi)               │
│   • dot_config/zsh/rc.d/*.zsh   ─ 10 numbered modules       │
│   • dot_config/starship.toml                                │
│   • dot_config/sheldon/plugins.toml                         │
│   • dot_config/ghostty/config                               │
│   • dot_config/git/config                                   │
│   • dot_claude/*  dot_pi/*   (templated via .tmpl)          │
│   • .secret  (chezmoi-ignored, lives outside git)           │
└─────────────────────────────────────────────────────────────┘
```

## Decisions & Why

### 1. Stay on `~/.config/nix-darwin/`, don't migrate to `~/nixos-config/`
`~/nixos-config` already has home-manager + agenix wired and is cross-platform — it's the obvious "best long-term home." But moving to it requires re-porting three custom derivations (Dropbox, Google Drive, Raycast), the `nix-homebrew` block, and the windsurf cask. That's a separate refactor with no functional payoff today. Two flakes is a real smell, but we treat it as scheduled tech debt, not a blocker. Single source of truth is a goal, not a gate.

### 2. Add home-manager as a darwin module, not a standalone CLI
home-manager can run two ways:
- **Standalone**: `home-manager switch` — separate activation from system rebuild
- **Darwin module**: `darwin-rebuild switch` rebuilds system + user atomically

We chose the module path because (a) one command to rebuild everything is operationally simpler, (b) the user profile and system never get out of sync, (c) rollback (`darwin-rebuild --rollback`) covers both layers in one shot. The cost is that home-manager updates require a system rebuild — fine for a personal Mac.

### 3. `useGlobalPkgs = true; useUserPackages = true`
Default home-manager behavior maintains its own `nixpkgs` — wasteful on disk and slow to evaluate. Setting `useGlobalPkgs` makes home-manager use the system's nixpkgs (single instance, single eval). `useUserPackages` puts the user profile under `~/.nix-profile` instead of a private store. Both are widely recommended best practices.

### 4. `home.packages`, **not** `programs.<tool>.enable`
Tempting to write `programs.starship.enable = true; programs.starship.settings = …` — home-manager has first-class modules for starship, fzf, zoxide, git, bat, etc., and they generate the config files for you.

We deliberately **don't** enable these because they would write to `~/.config/starship.toml`, `~/.gitconfig`, etc., **conflicting with chezmoi-managed files**. Two managers fighting over the same paths produces silent breakage. The rule is: one writer per file. So home-manager owns `bin/`, chezmoi owns `etc/`. Clean boundary.

If you ever want to migrate a config file *to* Nix, the recipe is: (a) add it to `.chezmoiignore` so chezmoi stops tracking it, (b) flip `programs.<tool>.enable = true` and port the settings, (c) `chezmoi apply` to clear the now-unmanaged file, (d) `darwin-rebuild switch` to write the Nix-managed version. One file at a time, no big-bang migration.

### 5. Move `gemini-cli` and `codex` from `environment.systemPackages` to `home.packages`
They're per-user dev tools, not system infrastructure. Convention: anything that authenticates as the user, holds a per-user config in `~/.<tool>`, or would be different per user belongs in `home.packages`. Things like Dropbox that have a system-level launchd agent and run as root belong in `environment.systemPackages`.

### 6. Set `users.users.martinfan.home`
home-manager's common module derives `home.homeDirectory` from `users.users.<name>.home`. nix-darwin doesn't auto-create user accounts on macOS (the account already exists in Open Directory), but it needs the home path declared so home-manager's evaluation knows where to write. Without this, `darwin-rebuild build` fails with `not of type 'absolute path'` (the value defaults to `null`).

## Benchmark: How to Evaluate Alternatives

If you ever consider a different setup, score candidates on these axes. Each gets 0–3 (worse → better).

| Axis | What it measures | How to test |
|------|------------------|-------------|
| **Reproducibility** | Can a fresh Mac produce a bit-identical environment? | Boot a new VM, run the activation command, diff `~/.nix-profile/bin/` against the source machine |
| **Atomic rollback** | Can a bad change be reverted in one command without leaving partial state? | Apply a change that breaks something, run the rollback, verify the broken state is gone |
| **Tool-version pinning** | Can you say "exactly this `ripgrep` version everywhere"? | Inspect the lock file or activation output for the exact store path |
| **Config diff readability** | Can you grok a year-old change from git log? | Read 5 random commits — do you understand what changed and why? |
| **Edit→apply latency** | How long from "edit a config" to "it's live"? | Time `darwin-rebuild switch` (cold and warm), `chezmoi apply`, etc. |
| **Drift tolerance** | What happens when something edits a managed file out-of-band? | `echo x >> ~/.zshrc` then re-apply — does the system warn, overwrite, or silently coexist? |
| **Secret hygiene** | How easy is it to commit a secret by accident? | Look at the workflow for `.secret` — does it actively block, or just rely on `.gitignore`? |
| **Cross-machine portability** | Can you stand up a Linux box from the same source? | Try it. nix-darwin specifically can't, but the home-manager + chezmoi layers can |
| **Onboarding cost** | Time for someone fluent in Unix but new to your stack to make a safe change | Have a friend try to add a CLI tool. Measure minutes |
| **Closure size on disk** | `du -sh /nix/store` and `du -sh ~/dotfiles` after a fresh install | Cheap to measure, surprisingly variable across approaches |

### Scorecard: Real Alternatives We Could Have Picked

Scoring is for *this* setup (single-user Mac, heavy AI-tool workflow). Different shop, different scores.

|  | **Hybrid (chosen)** | Pure chezmoi + Homebrew | Pure home-manager (no chezmoi) | Pure nix-darwin `systemPackages` | Nothing (ad-hoc brew + manual edits) |
|---|---|---|---|---|---|
| Reproducibility | **3** — `flake.lock` pins everything Nix-managed; chezmoi pulls deterministic source | 1 — Brewfile drifts; brew updates aren't pinned | **3** | **3** | 0 |
| Atomic rollback | **3** — `darwin-rebuild --rollback` covers system + user; chezmoi has `chezmoi diff` + git | 1 — git revert + manual reinstall | **3** | **3** | 0 |
| Tool-version pinning | **3** | 1 | **3** | **3** | 0 |
| Config diff readability | **3** — chezmoi shows raw zsh, not Nix string literals | **3** | 1 — multi-line Nix strings are noisy | 1 | 2 |
| Edit→apply latency | 2 — chezmoi apply <1 s, darwin-rebuild 5–60 s | **3** — chezmoi alone | 1 — every edit = full rebuild | 1 — every edit = full rebuild | **3** |
| Drift tolerance | 2 — chezmoi warns on drift; Nix layer is read-only | 2 | 1 — Nix overwrites silently if you edit a generated file | 1 | **3** |
| Secret hygiene | 2 — `.secret` is chezmoi-ignored; could be **3** with agenix | 2 | **3** with agenix integration | 2 | 0 |
| Cross-machine portability | 2 — chezmoi works anywhere; Nix layer needs Nix | 2 | 2 — needs Nix | 1 — macOS only | **3** |
| Onboarding cost | 2 — two systems to learn but each is shallow | **3** | 1 — Nix is the steep one | 2 | **3** |
| Closure size | 2 | 2 | 2 | 2 | **3** |
| **Total** | **24/30** | 20/30 | 22/30 | 19/30 | 17/30 |

**Read it as:** Hybrid wins because chezmoi keeps config text human-readable while Nix gives reproducibility and rollback. Pure home-manager comes close but loses on diff readability — multi-line Nix string interpolations age badly. Pure systemPackages loses because it can't manage user-scoped state (~/.config files, per-user package preferences). Ad-hoc wins only on "I'm in a hurry tonight."

### When the Scorecard Flips

- **Multi-user shared Mac** → Pure home-manager (or NixOS) wins; chezmoi has weaker per-user secret stories.
- **Cross-platform fleet (Mac + Linux + WSL)** → chezmoi-heavy with thin Nix wins; nix-darwin is macOS-only.
- **Production server** → Pure Nix (NixOS), no chezmoi; declarative everything.
- **Throwaway dev VM** → Ad-hoc; the overhead doesn't pay back.

## Workflows

### Add a new CLI tool
```bash
# 1. Verify it's in nixpkgs and check the version
nix eval --raw .#darwinConfigurations.Martins-Mac-mini.pkgs.<name>.version

# 2. Add it to home.nix → home.packages

# 3. Build and inspect first (catches eval errors before activation)
darwin-rebuild build --flake .#Martins-Mac-mini
ls -la result/sw/bin/<name>  # confirm the symlink

# 4. Activate
sudo darwin-rebuild switch --flake .#Martins-Mac-mini
```

### Pin a different version of a package
Edit `flake.nix` to add a `nixpkgs-pinned` input at a specific commit, then reference `pkgs-pinned.<name>` in `home.nix`. Or temporarily override with `nixpkgs.overlays = [(final: prev: { <name> = … })];`.

### Update everything
```bash
nix flake update                                              # bump nixpkgs / home-manager / etc.
darwin-rebuild build --flake .#Martins-Mac-mini               # preview
sudo darwin-rebuild switch --flake .#Martins-Mac-mini         # activate
chezmoi update                                                # pull dotfiles + apply
```

### Rollback a bad rebuild
```bash
sudo darwin-rebuild --rollback        # one generation back
# or
darwin-rebuild --list-generations
sudo darwin-rebuild switch --switch-generation <N>
```

### Migrate a config file from chezmoi to Nix (when ready)
1. Add the file to `.chezmoiignore` in `~/dotfiles`
2. `chezmoi apply` (no-op for the file now, but stops tracking)
3. `rm ~/.config/<file>` (chezmoi won't delete it for you)
4. Add `programs.<tool>.enable = true; programs.<tool>.settings = …;` to `home.nix`
5. `darwin-rebuild switch`

Don't do this in bulk. One file at a time, verify each.

## Brew Strategy

**Decision: drop Homebrew. Pure Nix going forward.**

The flake currently still imports `nix-homebrew` and declares one cask (`windsurf@next`). That's transitional. The endpoint is no brew at all — every Mac app declared as a custom Nix derivation alongside the existing `dropbox` / `google-drive` / `raycast` ones.

### Why not zerobrew or zigbrew?

You already have `/opt/zerobrew` on this machine and asked whether to switch to it (or zigbrew) instead of Homebrew. Short answer: **neither solves the actual problem.**

| Option | What it is | Verdict |
|---|---|---|
| **Homebrew** | The status quo. Mutable global state in `/opt/homebrew`. | Slow, races with Nix on `/opt/`, casks update out-of-band. The `cleanup = "zap"` setting is a footgun — it deleted Chrome and 25 formulae on the last activation. |
| **zerobrew** | Brew-compatible parallel prefix at `/opt/zerobrew`. You set it up as a "smart router" via `~/.local/bin/brew`. | Same model as Homebrew. Same drift problems. Just a different directory. Not declarative. |
| **zigbrew** | Zig-rewritten Homebrew alternative. Faster install. | Same model. Same drift problems. Faster doesn't fix declarativeness. |
| **Pure Nix (custom derivations)** | DMG fetched and unpacked by a Nix derivation, just like `dropbox`/`raycast` already are. | Declarative, reproducible, atomically rollbackable. Slightly more work per app upfront. **This is the answer.** |

The reason both brew alternatives lose: they replicate Homebrew's *implementation* but not its *interface contract* with Nix. Whatever lives outside the Nix store is, by definition, not part of the rebuild. zerobrew or zigbrew installs would still be invisible to `darwin-rebuild`, still missing from `flake.lock`, still un-rollbackable, and still capable of being out-of-sync between machines.

If you want a brew-like experience for **truly ad-hoc, throwaway installs** (testing a CLI you might delete tomorrow), keep `/opt/zerobrew` as a personal scratchpad. But it should never appear in the declarative system config. Two-tier rule: **declarative things in Nix, ad-hoc experiments in `/opt/zerobrew`** — never the other way around.

### Cask migration recipe

To convert `windsurf@next` (the only remaining brew cask):

```nix
windsurf-next = pkgs.stdenv.mkDerivation {
  pname = "windsurf";
  version = "next";  # or pin to a specific build hash
  src = pkgs.fetchurl {
    url = "https://windsurf-stable.codeiumdata.com/aarch64/Windsurf-darwin-arm64-Next.dmg";
    sha256 = "<run nix-prefetch-url to get>";
  };
  nativeBuildInputs = [ pkgs.undmg ];
  sourceRoot = ".";
  phases = [ "unpackPhase" "installPhase" ];
  installPhase = ''
    mkdir -p $out/Applications
    cp -r "Windsurf.app" $out/Applications/
  '';
  meta.platforms = [ "aarch64-darwin" ];
};
```

Then add it to `environment.systemPackages` and remove the `homebrew.casks` entry. After one rebuild, run `brew uninstall --cask windsurf@next` to clear the brew copy.

Once *no* casks remain in the homebrew block, set `homebrew.enable = false;` and the bridge is gone. `/opt/homebrew` becomes inert.

### The "zap" footgun, post-mortem

`onActivation.cleanup = "zap"` told brew to remove every cask not declared in the Nix flake — including ones you'd installed manually (Chrome, Docker Desktop, …). The first activation with `home-manager` wired in triggered this and silently destroyed apps. The setting is now `"none"` so out-of-band brew installs are left alone. **Never use `"zap"` unless every brew cask you care about is declared in the flake.**

## gemini-cli @preview

`pkgs.gemini-cli` in nixpkgs tracks `@latest` (currently 0.38.2). The user-visible config asks for `@preview` (currently 0.40.0-preview.4) — a Google-published npm dist-tag with newer agent features.

We carry a **fresh derivation** at `pkgs/gemini-cli-preview.nix` rather than `overrideAttrs` because nixpkgs's gemini-cli uses `buildNpmPackage (finalAttrs: …)`, and `overrideAttrs` does not propagate `version` into the inner `finalAttrs` closure. The build then fails with `gemini-cli-0.38.2-npm-deps` mismatching the new preview source's `package-lock.json`. A fresh `callPackage` of a near-verbatim derivation file sidesteps the closure issue.

The bump procedure is documented in the file's header comment. Three values change (version, src hash, npmDepsHash) and the recipe to compute each is one command.

## Open Tech Debt

- **Two flakes** (`~/.config/nix-darwin/` and `~/nixos-config/`). Consolidate into one when there's a reason — until then, this one is the active boss.
- **No agenix yet on this Mac.** `~/.config/zsh/.secret` is currently chezmoi-ignored and lives plaintext outside git. Acceptable for solo use; upgrade to agenix when threat model demands.
- **Homebrew bridge still wired in** for `windsurf@next`. Convert to a custom derivation per the recipe above, then `homebrew.enable = false`.
- **`/opt/zerobrew` is still on `PATH`** (per `dot_zshenv`). Now that Nix owns the same tools at higher priority via `~/.nix-profile/bin`, zerobrew is mostly dead weight. Audit and remove its PATH entries when convenient.
- **`~/.nix-profile/bin` may not be on `PATH`.** Check `echo $PATH` after a fresh shell — if missing, the dotfiles' `dot_zshenv` needs `_zb_path_append "$HOME/.nix-profile/bin"` (preferably first).
- **`programs.zsh.enable` is intentionally off.** If you ever want Nix-managed completions, history, etc., the migration path is documented above — do not flip this casually.
- **Chrome, Docker Desktop, others got zapped** by the previous `cleanup = "zap"`. Chrome's bits are still at `/opt/homebrew/Caskroom/google-chrome/139.0.7258.128/`. Reinstall via `brew reinstall --cask google-chrome` (or convert to a Nix derivation if you want it declarative).
