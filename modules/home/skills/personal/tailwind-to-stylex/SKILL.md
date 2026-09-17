---
name: tailwind-to-stylex
description: Migrate any web frontend (React, Preact, Solid, Vue, Svelte, Qwik; Vite, Next.js, webpack, Rspack, esbuild; SPA, SSR, static site, Electron, browser extension; Tailwind v3 or v4; any headless component library) from Tailwind CSS to StyleX with exact rendering parity, or prove two builds of any web UI render identically (computed styles in every state, both colour schemes, pixels). Use when porting utility classes to StyleX, or when a styling refactor must be verified as pixel-for-pixel unchanged.
---

# Tailwind → StyleX, exact parity

The migration is a **parity loop**: convert, then prove with a **parity round** — a headless Chrome capture of every page in every state, diffed node by node against the pre-migration build — and fix until the round is **green** (zero differences). "Looks the same" is never the bar; the computed values are.

Two rules hold from here to the end. They are not step ordering — they are the failure this skill exists to prevent:

- **Tailwind and its helpers stay installed until a parity round is green.** Removing the dependency, the `@import`, or the PostCSS/Vite plugin any earlier deletes the CSS that every not-yet-converted file still references. The app then renders unstyled while typecheck, lint, unit tests and the build all stay green — and the CSS bundle *shrinks*, so size metrics read the damage as a win. Step 6 is last for this reason.
- **Scope is the whole app, not the files you picked.** File groups are a work split, never a definition of "done". One utility class left anywhere means the conversion is unfinished, whatever the groups say.

Reference, read when its step arrives:

- [`SPEC-TEMPLATE.md`](SPEC-TEMPLATE.md) — the project spec every agent reads; the intake step fills it.
- [`INTEGRATION.md`](INTEGRATION.md) — StyleX wiring per bundler and per framework, the component-API prop.
- [`MAPPING.md`](MAPPING.md) — how each utility becomes a StyleX declaration (v4 tables with v3 deltas), cascade traps, dark-mode strategies, component-library attribute vocabularies.
- [`PARITY.md`](PARITY.md) — `scripts/parity.ts` hosts and config, and the capture artefacts that masquerade as bugs.
- [`WORKFLOW.md`](WORKFLOW.md) — the intake / convert / review workflow templates in `workflows/`.

## 0. Intake → spec

The migration target is **ALWAYS the project in the active working directory or worktree**. Never search the machine for external repos, past migration targets, or historical references.

Run `workflows/intake.js` (or inspect the current project yourself) and fill `SPEC-TEMPLATE.md` to generate `SPEC.md` in the current project root. Capture: framework and the StyleX call it needs (`props` vs `attrs`), bundler and the build that renders the UI, Tailwind major and dark-mode strategy, component library and its state attributes, merge/variant helpers, every global rule that outranked utilities, the exact gate commands, the pages and states to capture, file groups.

Done when: every row of the spec's stack and gate tables has a value or a `TBD` with what to check, and the spec names the parity host.

## 1. Freeze the ground truth

Build the current app with its production build and keep the whole output as the **baseline build** (e.g. in `.parity/baseline-build/` or an external scratch directory). Pretty-print its compiled Tailwind CSS (`prettier --parser css`) into a **ground-truth** file (e.g. `.parity/ground-truth.css`): every utility's exact declarations in cascade order. Every value written later is looked up here, never recalled from memory — the majors differ (`MAPPING.md`) and projects override the theme. Buildless/CDN Tailwind: the ground truth is the baseline capture's computed styles.

Done when: baseline build + ground truth are saved, and a parity capture of the baseline exists that **shows the real UI** — open a few screenshots and node counts; a page that renders an error or empty state (missing fixtures, a preload bridge the harness does not provide, an unseeded session) compares equal against itself in every later round and proves nothing. That capture proves the harness on this project (`PARITY.md` § Hosts) before anything changes.

## 2. Wire the infrastructure alone

Before any component moves, land and build-verify:

- the StyleX plugin per `INTEGRATION.md`, attached only to the build that renders the UI, lightningcss targets pinned to the project's browser floor, `aliases` for path aliases;
- **tokens**: `stylex.defineVars` in a `*.stylex.*` file, every custom property under its historical name (`'--primary'`, `'--radius'`, whatever the project calls them); dark values as `@media` keys, or as a `createTheme` for class-driven dark mode (`MAPPING.md` § Dark mode);
- **markers** (`stylex.defineMarker`) for descendant rules (`[&_svg]:size-4`) and `group-*` variants, read back with `stylex.when.*`;
- a plain global stylesheet holding only what StyleX cannot express: the preflight reset verbatim, the document shell, **structural rules** (parent → child utilities keyed on `data-*` attributes), reduced motion;
- shared leaf components (icons) take the style-forwarding prop named in the spec.

Done when: the build passes, outputs the migration does not touch (server bundle, workers, content scripts, other entry points) are byte-identical to the baseline, and the StyleX CSS lands in the asset every migrated page loads.

## 3. Convert by file group

Run the convert workflow over the spec's file groups (`WORKFLOW.md`, which also says how to do it without the Workflow tool); agents look every utility up in the ground truth and resolve the **effective declaration** per element before writing it.

Done when: a **repo-wide** search finds no utility strings anywhere in the app — not "none in the groups this agent owned", which is satisfiable by owning three files — and no merge/variant-helper imports or class props (per the spec's component API) remain; the spec's gate is clean for them; owned tests pass with their styling assertions repointed at the StyleX objects. Run the search yourself and paste the count; a group list that does not add up to the spec's §11 inventory means groups are missing, not that the step is done.

## 4. Parity rounds until green

Run a round: build candidate, capture baseline and candidate with the same harness and config, compare. Classify every difference before touching code — most early ones are capture artefacts (`PARITY.md` § Artefacts), the rest are candidate bugs with a ground-truth citation. Fix, rebuild, repeat.

Done when: `compare` exits 0 — every scenario reports 0 style/DOM diffs and 0 pixels, no scenario missing or without a screenshot.

## 5. Review what the harness cannot render

States no scenario reaches (`aria-invalid`, disabled controls, highlighted options, forced-colors, transient animation attributes) get the review workflow: two lenses per file (value exactness, cascade/precedence), independent refuters per finding, one fixer per file. Then one more parity round.

Done when: every confirmed finding is applied and the round is still green.

## 6. Finish

Only once step 4 is green: remove the old styling dependencies and helpers (Tailwind, its PostCSS/Vite plugin, `tailwind-merge`, `cva`, `clsx` if only used for classes), add `@stylexjs/eslint-plugin` where the spec's linter is ESLint, run the full gate, and smoke-test dev mode (a separate code path — `INTEGRATION.md` § Dev mode).

Then rebuild and run the **dangling-class check**. It needs no browser, takes seconds, and is the one gate that fails loudly on the failure mode above — markup still referencing utility CSS that removal just deleted:

```bash
rg -o 'class(Name)?="[^"]+"' src --glob '!*.test.*' \
  | rg -o '\b[a-z-]+-[a-z0-9./\[\]%-]+\b' | sort -u \
  | while read -r c; do rg -qF ".$c" <the built CSS> || echo "DEAD: $c"; done
```

Any output means the build ships elements whose styles no longer exist: restore the dependency, finish step 3, and re-run step 4. A clean run plus a green round is what licenses the removal.

Report: scenarios, elements and forced states compared, dropped rules with reasons, states left unverified. Bundle-size figures are not evidence of parity — a CSS bundle that shrank because its consumers still reference the deleted rules shrinks exactly the same way.
