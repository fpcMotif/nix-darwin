# Experiment: pure Fish as the interactive shell (#385)

## At a glance

The committed Zsh setup (`aa9f1d7`) takes about 145 ms to its first prompt, 60 ms of it Starship.
One switch, `martin.shell.interactive = "fish"`, moves every terminal to a native Fish config with a 34 ms prompt.
Unchanged: `/bin/zsh` still runs scripts, PATH and aliases are shared, and switching back restores the Zsh config.

## What changes

`martin.shell.interactive` (`modules/home/shell/options.nix`) selects one shell. Only the selected shell's Home Manager config is generated. Fish never sources Zsh config or starts Zsh. The Zsh history file and the shared PATH tiers stay as they are.

| Surface | `"zsh"` (baseline) | `"fish"` (this branch's host setting) |
|---|---|---|
| Login shell (`dscl UserShell`) | `/bin/zsh` | `/run/current-system/sw/bin/fish` |
| Exported `SHELL` | `/bin/zsh` | `/run/current-system/sw/bin/fish` |
| `/etc/shells`, `/etc/fish` | zsh only | zsh and fish; nix-darwin fish config via babelfish |
| Ghostty `shell-integration` | `zsh` | `fish` |
| tmux `default-shell` / `default-command` | zsh / `zsh -l` | fish / `fish -l` |
| Zed terminal | zsh | fish |
| Generated files | `.zshenv`, `.zshrc` | `.config/fish/config.fish`, `functions/` |

nix-darwin writes the login shell only for users in `users.knownUsers`. The primary user is now listed with `uid = 501`. nix-darwin refuses to delete the primary user and deletes no user with a uid of 501 or lower. The same list already held the Nix build users.

The host's nightly auto-switch is off on this branch. A switch to `origin/main` removes Fish from the system profile but leaves the login shell pointing at it. New terminals and SSH logins would then fail. The `justfile` preflight now skips a launchd job whose plist this generation does not install. Without that, every `just build` would ask for sudo to revive the disabled auto-switch job.

## How Fish is configured

Everything is native Fish, declared in Nix. There is no plugin manager, no startup download, and no universal variable written by config.

| Need | Baseline Zsh | Fish |
|---|---|---|
| Prompt | Starship (`git`/`jj` probes each prompt) | `fish_prompt` from builtins only: directory, status-colored `❯`, `❮` in vi normal mode |
| Vi editing | ZLE `viins`/`vicmd` | `fish_vi_key_bindings` |
| Insert-mode reflexes | `^A ^E ^K ^U ^W ^P ^N` | same keys; `^K`/`^W` are Fish's own |
| Edit line in `$EDITOR` | `vv`, `^X^E` | `alt-e`, `alt-v` (Fish native; see omissions) |
| History search | fzf `^R`, prefix Up/Down | fzf `^R`, Fish's substring Up/Down |
| Suggestions, highlighting | off | Fish native, on |
| Search plane | `^G f/d/k`, fzf-git ctrl chords | same chords; upstream `fzf-git.fish` |
| direnv, zoxide, fzf, Yazi | HM Zsh integrations | HM Fish integrations |
| worktrunk | `wt config shell init zsh` rendered at build | same for Fish |
| Aliases | Zsh aliases | abbreviations from the same list (`modules/home/shell/shared.nix`) |
| AI wrappers, `du`, `ab`, `jot`, `vault` | interactive `.zshrc` functions | interactive-only Fish functions; `env -u` scopes env removal to the child |
| Helpers (`fif`, `fkill`, `dev-info`, `ghostty-*`, `obd-*`, `oc-*`) | `.zshrc` functions | autoloaded Fish functions (no startup cost) |
| PATH | HM session tiers, `typeset -U` | HM session tiers, first-seen dedup in `shellInit` |
| `TERMINFO_DIRS` | defaults, then inherited, deduplicated | same |
| OrbStack | `init.zsh` in login | its own `init2.fish` in login |

Some wrappers share a real command's name: `claude`, `cc`, `codex`, `opencode`, `amp`, `crush`, `droid`, `pi`, `du`, `ab`, `jot`, and `vault`. They exist only in interactive Fish, as they did in Zsh. Fish autoloads user functions in scripts too. So an autoloaded `grep` or `cc` would have changed what `fish -c` and Fish scripts run. `grep` is an abbreviation for `rg` for the same reason.

### Deliberate omissions

- `vv` in normal mode and `^X^E` in insert mode are not bound. Fish waits indefinitely on an ambiguous key prefix. Binding `vv` would stall visual mode after `v`, and `^X` alone is clipboard copy. `alt-e` opens the line in `$EDITOR` in every mode.
- History is not imported. `~/.config/zsh/.history` stays as it is. Fish keeps its own history in `~/.local/share/fish/fish_history`. Fish shares history between sessions on `history merge`, not live.
- `~/.zshrc.local` (the `graff`/`harness` wrappers) is user-owned and not ported. Its Fish home is `~/.config/fish/conf.d/`, which Fish reads natively.
- HM's man-page completion builds are off. They add one derivation per package. The auto-update source-build guard counts each one as a source build. Fish's shipped completions and each package's vendor completions still load. On its first interactive start, Fish scans man pages once in the background.
- Non-interactive `z` for agent shells stays a Zsh concern. Agents run `/bin/zsh`, which no longer reads the Home Manager `.zshenv` when Fish is selected. An agent started from a Fish session inherits the full environment. A `zsh -lc` started from a clean environment gets nix-darwin's environment but not `z` or the Home Manager variables.

### Known gaps

- The `^G f` content search replaces the current token with the chosen path. The Zsh widget appends the path after the search term instead. That reads as a Zsh bug, since the option text says "inserts the path at cursor".
- Neovim and other tools that run `$SHELL -c` now run Fish syntax. This config's fzf commands are Fish-compatible, and `fzf-git.fish` runs its script with bash.
- Claude Code's deny rules cover `~/.zsh_history` and `~/.zshrc`, not Fish's history or config. Changing agent permissions is out of scope for this issue.

## Evidence

All measurements: Apple M4 Pro, macOS 27.0 (26A5425a), hyperfine 1.20.0, `/bin/zsh` 5.9, Fish 4.9.3.
Baseline is `aa9f1d7` home-files `nqa54hr6…`. The candidate is this branch's home-files `bvv7dk6c…`. Both ran before activation, from built configs.

### Startup (hyperfine, 20 warmup runs, inherited session environment)

| Mode | Zsh baseline (Starship) | Zsh, no Starship | Fish + Starship | Fish candidate |
|---|---|---|---|---|
| bare (`zsh -f -i` / `fish --no-config -i`) | 2.8 ± 0.5 ms | 2.9 ± 0.4 ms | 7.0 ± 0.4 ms | 7.3 ± 3.8 ms |
| `-c exit` | 3.4 ± 1.9 ms | 3.0 ± 0.4 ms | 8.9 ± 3.1 ms | 7.8 ± 0.5 ms |
| `-l -c exit` | 3.2 ± 0.4 ms | 3.4 ± 2.4 ms | 8.9 ± 1.3 ms | 8.4 ± 2.5 ms |
| `-i -c exit` | 80.6 ± 8.8 ms | 67.4 ± 1.7 ms | 36.6 ± 5.6 ms | 24.4 ± 2.8 ms |
| `-lic exit` | 82.6 ± 16.0 ms | 69.3 ± 5.2 ms | 36.1 ± 0.9 ms | 25.1 ± 5.4 ms |

### First prompt (pty, login shell, launchd-sized environment, 3 warmup + 20 runs)

`scripts/benchmark-first-prompt.py` starts the shell the way a terminal does, waits for the prompt, then types one command.

| | Zsh baseline (Starship) | Zsh, no Starship | Fish + Starship | Fish candidate |
|---|---|---|---|---|
| First prompt, median (p90) | 144.5 ms (170.4) | 84.2 ms (113.5) | 79.6 ms (105.6) | 34.2 ms (37.3) |
| Command lag, median | 0.3 ms | 0.2 ms | 0.6 ms | 0.6 ms |

"Zsh, no Starship" is the baseline built with `martin.prompt.starship.enable = false`, so Zsh draws its native `%1~ %#` prompt. "Fish + Starship" is this branch with `programs.starship.enableFishIntegration = true`. These two columns separate the prompt's cost from the shell's. Starship adds about 60 ms to Zsh and 45 ms to Fish. Every run starts in an empty directory that is not a repository. Estimate, not measured: in a Git or Jujutsu checkout, Starship's `git` and `jj` segments cost more. The native Fish prompt runs no command in any directory.

Fish is about 2.4× slower for `-c` scripts (+4.4 ms) and much faster to an interactive prompt.
Estimate: after activation, Fish's clean start runs nix-darwin's babelfish environment instead of `path_helper`. Both are a few builtins, so the first-prompt figure should not move much. Rerun `just benchmark-startup` after the switch to confirm.

### Behavior checks

| Check | Result |
|---|---|
| `unit-fish-shell` (sandboxed Fish, all four modes; 13 groups) | pass |
| `unit-shell-switch` (one shell's config per setting) | pass |
| `integration-configurations-eval` (Darwin, 100 cases incl. 5 new) | pass |
| `unit-zsh-vi-mode` (Zsh keymaps under `"zsh"`) | pass |
| `nix flake check` (aarch64-darwin, all checks) | pass |
| `darwinConfigurations.f.system` build, including `/etc/fish` | pass (`darwin-system-26.11.4cff07d`) |
| Linux host (`x230`) evaluation: switch stays `"zsh"`, Fish surfaces have no Darwin-only text | pass (evaluated on Darwin; the full purity test runs on the Linux CI builder) |
| `verify-session-path` Zsh baseline, built config | 62 passed, 0 failed, 1 skipped |
| `verify-session-path` Fish candidate, built config | 56 passed, 6 failed, 1 skipped |
| same, with `VSP_SYSTEM_ENV` (nix-darwin environment emulated) | 62 passed, 0 failed, 1 skipped |

The skip in every run is the mbx delegate check. The shim and the Nix cargo report the same version string, which cannot prove delegation.
The six Fish failures before activation share one cause. `/etc/fish` does not exist until the switch, so nothing sets `__NIX_DARWIN_SET_ENVIRONMENT_DONE`. Without that guard, a forked login Fish runs macOS `path_helper`. `path_helper` moves `/usr/bin` ahead of the Nix tiers. After the switch, `/etc/fish/nixos-env-preinit.fish` runs nix-darwin's `set-environment` first. With that emulated, all six pass.
Fish runs add 8 warnings for Fish's own `man` wrapper function. The remaining warnings are the intended `droid` and `opencode` wrappers, which Zsh also reports.

## Trial

Record the current state first:

```bash
darwin-rebuild --list-generations | tail -n 3
```

```bash
dscl . -read /Users/martinfan UserShell
```

Switch to the branch:

```bash
sudo darwin-rebuild switch --flake ~/nix-config.codex-pure-fish-experiment#f
```

Then confirm, in a new Ghostty window, a new tmux pane, and a Zed terminal:

```bash
ps -o comm= -p $fish_pid; echo $SHELL; dscl . -read /Users/martinfan UserShell
```

```bash
VSP_SHELL=fish bash ~/nix-config.codex-pure-fish-experiment/scripts/verify-session-path.sh
```

```bash
bash ~/nix-config.codex-pure-fish-experiment/scripts/benchmark-shell-startup.sh
```

## Rollback

Preferred: set `shell.interactive = "zsh";` and `autoSwitch.enable = true;` in `hosts/darwin/default.nix`, then switch. nix-darwin writes `/bin/zsh` back as the login shell, because the user stays in `knownUsers`. Home Manager regenerates `.zshenv` and `.zshrc` and removes the Fish config. Both history files stay.

Generation rollback also works, with one extra step. Pre-experiment generations do not manage the login shell, so reset it by hand before the Fish binary disappears:

```bash
chsh -s /bin/zsh
```

```bash
sudo darwin-rebuild --rollback
```

Pre-activation evidence for rollback comes from building this branch with the switch set to `"zsh"`. That build gives login shell `/bin/zsh` and `SHELL=/bin/zsh`. Ghostty, tmux, and Zed start Zsh, and there is no Fish config. Its `.zshenv` is byte-identical to the baseline's. Its `.zshrc` differs only in `_unset_ai_env`, which now lists the same 14 names on one line. The Ghostty config differs in one comment. A live rollback has not been run.

## Recommendation

Run the live trial; do not merge yet. The measurements support the speed claim. Fish reaches its first prompt about 4× faster than the committed setup. It is about 2.5× faster than Zsh without Starship. Keeping Starship on Fish gives up most of that gain (79.6 ms, level with Zsh without Starship). The cost is about 4 ms more per `fish -c`, a mode nothing here runs routinely.

Adoption should wait for the trial checks that no build can give:

1. Ghostty, tmux, and Zed each start Fish (`ps` on the shell PID), with the vi and `^G` chords working by hand.
2. `verify-session-path` passes on the live dotfiles without `VSP_SYSTEM_ENV`.
3. Claude Code and Codex still run commands normally with `SHELL` set to Fish.
4. A preferred rollback round trip restores `/bin/zsh` and both history files.

Independent of Fish: turning off Starship alone saves about 60 ms per prompt. That is the cheaper step to weigh in #380.
