# Workflow templates

Three Workflow-tool scripts in `workflows/`, parameterised through `args` (absolute paths). Model defaults to `sonnet`; pass `model`/`effort` to change. Invoke each by reading the template and passing its text as `script` (the tool accepts `scriptPath` only for files it wrote itself).

Without a Workflow tool, the scripts are still the method: `agent`/`parallel`/`phase` only distribute the prompts each script builds (`prompt(g)` in convert.js; `discoverPrompt`/`specPrompt` in intake.js; `reviewPrompt`/`verifyPrompt`/`fixPrompt` in review.js). Generate each prompt yourself and carry it out one group, file, or lens at a time. For review.js keep the independence the script relies on: run the two lens passes without reading each other's findings, refute every finding adversarially from the ground truth as `verifyPrompt` demands, and default to not-real when you are your own only refuter.

## `intake.js` — discover the project, write the spec

```js
Workflow({ script: '<contents of workflows/intake.js>', args: {
  repo: '.',                                          // defaults to current project root (process.cwd())
  out: './SPEC.md',                                   // defaults to <repo>/SPEC.md
  groundTruth: './.parity/ground-truth.css',          // optional, if already produced
  baseRef: 'main'                                     // optional: pre-migration ref if tree is mid-migration
}})

Six parallel readers (stack, Tailwind + dark mode, components + helpers, cascade overrides, gate commands + test idioms, pages + states), then one writer fills `SPEC-TEMPLATE.md`. Read the spec, resolve its `TBD` items, and fix the file groups by hand before converting.

## `convert.js` — one agent per disjoint file group

```js
Workflow({ script: '<contents of workflows/convert.js>', args: {
  repo: '.', spec: './SPEC.md', groundTruth: './.parity/ground-truth.css',
  commands: { format: 'pnpm prettier --write', lint: 'pnpm eslint', typecheck: 'pnpm tsc --noEmit -p .', test: 'pnpm vitest run' },
  groups: [
    { key: 'A', files: ['<shared primitives…>'], tests: [], notes: '<overrides that apply here, from spec §3>' },
    { key: 'B', files: ['<views…>'], tests: ['<their tests>'], notes: '…' }
  ]
}})

Agents edit in place (groups own disjoint files), look every utility up in the ground truth, write effective declarations, run the gate commands on their files, update the tests they own, and return `{ group, files, dropped: [{ file, utility, reason }], notes, uncertainties, gate }`. Infrastructure (tokens, markers, global stylesheet, shared leaf components) must already be migrated; agents never run the build or the whole suite. Omit a command the project lacks; the agent reports `n/a`.

## `review.js` — two lenses, two refuters, one fixer per file

```js
Workflow({ script: '<contents of workflows/review.js>', args: {
  repo: '.', spec: './SPEC.md', groundTruth: './.parity/ground-truth.css',
  baseRef: 'main', files: ['<every migrated file>'],
  commands: { format: '…', lint: '…', typecheck: '…' },
  harnessDiffs: './.parity/snap-candidate/diffs.json'  // optional
}})

Per file: value-exactness and cascade/precedence reviewers (merge conflicts, global overrides, order-dependent pairs, hover/dark nesting per Tailwind major and dark strategy, attribute keys per component library, structural attributes, dropped-rule reachability, DOM identity, SSR render-time branching), findings deduplicated by `(line, property, element)`, each refuted by two independent skeptics (real only if both agree), one fixer per file. Run it after the first green parity round; it covers states the harness cannot render.
