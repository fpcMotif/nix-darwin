# Defer a `martin.ai.enable` cluster toggle until a second real adapter exists

Status: deferred

## The candidate

Handoff D (`ai-cluster-enable-seam`, architecture review 2026-07-02) proposed one
cluster-level toggle, `martin.ai.enable` (default `true`), gating 10 of the 19 unconditional
`modules/home` fragments — `claude.nix`, `ai-cli.nix`, `ai-model-routing.nix`, `droid.nix`,
`amp.nix`, `opencode.nix`, `crush.nix`, `skill-router.nix`, `cursor.nix`, `zed.nix` — behind a
single seam declared once and read from each module's own `config = lib.mkIf
config.martin.ai.enable { ... };`, matching the existing `ghostty.nix`/`prompt.nix` pattern.
The handoff set its own decision test explicitly: does a second *real* profile-shape adapter
exist (the staged Omakub Home Manager profile), or is its absence dispositive — with the
countervailing fact that `wsl`/`x230`/`vm-aarch64-utm` already evaluate the full cluster in the
CI eval matrix today, unlike Omakub.

## Decision

Deferred. Record this reasoning so a future architecture review doesn't re-suggest the same
seam without new facts. This is not a rejection of the seam's design (an empirical spike proved
it mechanically sound) — it's a "no adapter has earned this yet" call, matching Simplicity
First's own bar for the two seams that do exist.

## Reasoning (from adversarial review — 3 independent judges per lens, 9 verdicts total)

**Correctness lens (3/3 verdict: safe to add).** An empirical spike
(`explore/ai-cluster-enable-seam`, commit `a40f0e7`) implemented the full patch — a new
`modules/home/ai-cluster.nix` declaring the option, all 10 modules mechanically wrapped
(`config = lib.mkIf config.martin.ai.enable { <unchanged body> };`, threading `config` into any
module header that lacked it) — and proved it a no-op at the default:
`darwinConfigurations.f`'s `home.file`/`home.packages` attribute sets, and its
`system.build.toplevel` derivation path, are byte-identical before and after the patch; the same
`home.file` identity holds for `nixosConfigurations.wsl`/`x230`. Flipping the option off via a
pure `.extendModules` override (no file mutation) cleanly removes exactly the ~40 AI-cluster
`home.file`/`xdg.configFile` entries while every unrelated module (zsh, git, ghostty, ssh, jj,
kitty, tmux, yazi) and the deliberately-excluded `lsp.nix` stay untouched — verified by direct
`hasAttr` probes, not just a name-set diff. `lib.mkIf`'s laziness on a false condition also means
a disabled cluster skips real derivation work (`pkgs.martin.droid`, `crush.nix`'s NUR fetch,
`ai-model-routing.nix`'s `python3.withPackages` env), not merely omits entries from a list. All
three judges are explicit, though, that this only answers "is it safe to land" — a narrower
question than the one the handoff actually poses.

**Simplicity lens (3/3 verdict: defer).** `hosts/wsl/default.nix`, `hosts/x230/default.nix`, and
`hosts/vm-aarch64-utm/default.nix` were read directly and confirmed to make **zero** `martin.*`
assignments — grepping all three for `martin\.` returns nothing. They inherit the exact same
`modules/home` module set as the Mac via `lib/mkSystem.nix`'s unconditional
`home-manager.users.${user} = import ../modules/home;`, with no host-level decision ever made
about it. `ARCHITECTURE.md` itself labels them "inactive scaffolds... lower priority than Mac
and future Omakub... not production until evaluated on real Nix systems" — the same "not yet
real" register it uses for Omakub, which explicitly does **not** exist as a flake output pending
an unresolved do-not-add-until list (exact Linux architecture, username/home path, single- vs
multi-user Nix, shared-package scope, which config stays unmanaged). `home-linux-purity-test.nix`
evaluating the full cluster on `wsl`/`x230` is a portability **guardrail** (no Darwin-only paths
leak into a Linux host), not evidence that any host has ever exercised, or asked for, a choice to
disable the AI cluster — the seam's only real beneficiary today would be CI-eval-surface hygiene
on hosts nobody runs, not a live consumer's stated need. That doesn't clear the "second adapter"
bar the existing `ghostty.nix`/`prompt.nix` seams were held to.

**Future-proofing lens (3/3 verdict: defer).** The retrofit is proven purely mechanical (a flat,
syntactic wrap per file — the spike itself is now the exact recipe) and does not compound with
time, so nothing is lost by waiting. Committing to **one** coarse `martin.ai.enable` boundary now
also risks guessing wrong: the module list mixes two different consumer shapes — headless
agent-CLI tooling (`claude.nix`, `ai-cli.nix`, `ai-model-routing.nix`, `droid.nix`, `amp.nix`,
`opencode.nix`, `crush.nix`, `skill-router.nix`) and editor-AI integration bundled into GUI
editors (`cursor.nix`, `zed.nix`) — and `ARCHITECTURE.md`'s own open Omakub question ("which
packages are shared with the Mac") is precisely the fact that would resolve whether those two
shapes belong under one flag or two. Guessing the boundary today and re-scoping later if Omakub's
real owner wants, say, Zed without Droid, is strictly more total work than defining the seam once
when the requirement is known.

**Out of scope on independent grounds, not timing.** `modules/home/lsp.nix` stays excluded:
its own header comment lists Neovim's built-in LSP client as a first-class consumer alongside
Claude/Codex, so gating it behind `martin.ai.enable` would be a correctness bug (an
AI-declining, Neovim-using host would lose language servers), not premature structure.
`modules/home/packages.nix` stays ungated: it has no existing AI/general segregation (`home.packages
= commonPackages ++ lib.optionals isDarwin darwinPackages;`, a two-way Darwin/common split only),
and most AI-CLI binaries are actually installed via `home.file` PATH symlinks in their own
modules (`droid.nix`, `opencode.nix`, `amp.nix`, `crush.nix`), not via `packages.nix` — cleanly
separating it would be real, undone refactor work, and doing it before Omakub's shared-package
question is answered risks the same premature-granularity guess as the single-vs-split-toggle
question above.

## What would change this decision

- `homeConfigurations.martinfan-omakub` becomes a real flake output with stated package/config
  requirements — at that point decide the toggle's granularity (single flag vs. split
  agent-CLI/editor-AI) against Omakub's actual needs, not a guess.
- Any of `wsl`/`x230`/`vm-aarch64-utm` is promoted from "inactive scaffold" to "active" per
  `ARCHITECTURE.md`'s own maintenance vocabulary, and its owner states a concrete need to disable
  some or all of the AI cluster.
- CI eval/build time or flakiness attributable to the AI-cluster modules on the inactive scaffold
  hosts becomes a measured, real pain point — not merely a theoretical laziness benefit. This is a
  legitimate, Omakub-independent reopening trigger worth naming on its own.
- Absent one of the above, re-litigating this exact `martin.ai.enable` shape should link back to
  this ADR rather than re-opening the same three questions.
- The empirical spike (`explore/ai-cluster-enable-seam`, worktree `wf_07f1bdc8-160-3`, commit
  `a40f0e7` — rebase onto current `main` before reuse, since its base has since diverged) is kept,
  not deleted, as the validated retrofit recipe for whichever trigger above fires first.

## References

- Handoff D: `/private/tmp/handoff-nix-config/handoff-D-ai-cluster-enable-seam.md`
- `lib/mkSystem.nix:~59-66` (unconditional `home-manager.users.${user} = import ../modules/home;`
  wiring shared by every host)
- `ARCHITECTURE.md` "Linux / Omakub plan" and "WSL, X230, and VM scaffolds" sections
  (do-not-add-until list; "inactive scaffolds... not production until evaluated on real Nix
  systems")
- `tests/integration/home-linux-purity-test.nix`, `tests/integration/configurations-eval-test.nix`
  (the CI eval matrix the handoff's Position 2 leans on)
- `modules/home/lsp.nix:1-14` (header documents Neovim as a first-class consumer)
- `modules/home/packages.nix:4,123` (`commonPackages`/`darwinPackages` split only, no AI
  segregation)
- Empirical spike: branch `explore/ai-cluster-enable-seam`, commit `a40f0e7`
