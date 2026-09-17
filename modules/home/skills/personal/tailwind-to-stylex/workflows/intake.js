export const meta = {
  name: 'tailwind-to-stylex-intake',
  description: 'Discover a project\'s stack, Tailwind version, dark-mode strategy, component library, global overrides, gate commands, and pages; write the migration spec from SPEC-TEMPLATE.md',
  phases: [
    { title: 'Discover', detail: 'six parallel readers, one fact area each' },
    { title: 'Spec', detail: 'one writer fills SPEC-TEMPLATE.md' },
  ],
}

// args: { repo?, skill?, out?, groundTruth?, baseRef?, model?, effort? }
//   repo        project root (defaults to process.cwd())
//   skill       tailwind-to-stylex skill directory (defaults to auto-detected skill directory)
//   out         path where SPEC.md is written (defaults to <repo>/SPEC.md)
//   groundTruth path of the compiled Tailwind CSS, if already produced
//   baseRef     git ref of the pre-migration tree when the working tree is already mid-migration
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const defaultSkillDir = typeof __dirname !== 'undefined'
  ? path.dirname(__dirname)
  : (typeof import.meta !== 'undefined' && import.meta.url ? path.dirname(path.dirname(fileURLToPath(import.meta.url))) : process.cwd())

const repo = path.resolve(args?.repo || process.cwd())
const skill = path.resolve(args?.skill || defaultSkillDir)
const out = path.resolve(args?.out || path.join(repo, 'SPEC.md'))
const groundTruth = args?.groundTruth ? path.resolve(args.groundTruth) : null
const baseRef = args?.baseRef || null
const model = args?.model || 'sonnet'
const effort = args?.effort || 'high'
const FACTS = {
  type: 'object',
  properties: {
    area: { type: 'string' },
    facts: {
      type: 'array',
      items: {
        type: 'object',
        properties: { key: { type: 'string' }, value: { type: 'string' }, evidence: { type: 'string' } },
        required: ['key', 'value', 'evidence'],
      },
    },
    unknowns: { type: 'array', items: { type: 'string' } },
  },
  required: ['area', 'facts', 'unknowns'],
}

const AREAS = [
  {
    key: 'stack',
    prompt: `AREA: stack. Determine: UI framework and version (package.json, entry files), whether components are JSX (className) or template-based (class / :class / class:), bundler or meta-framework and version, the build(s) that render UI vs sibling builds (workers, content scripts, server), rendering mode (CSR / SSR + hydration / SSG / islands), browserslist or target floor, TypeScript or plain JS, path aliases (tsconfig paths, vite resolve.alias), and the existing dev-server URL/port. From ${skill}/INTEGRATION.md choose the StyleX wiring for this bundler and say where the plugin call goes and which CSS asset the atomic CSS must land in.`,
  },
  {
    key: 'tailwind',
    prompt: `AREA: Tailwind. Determine the Tailwind major (package.json, tailwind.config.* vs @import 'tailwindcss' CSS-first), the dark-mode strategy (v3 darkMode config: 'media' | 'class' | ['selector', …]; v4 @custom-variant dark or default media), the theme customisations (tailwind.config theme.extend / @theme tokens, custom --radius etc.), plugins (tailwindcss-animate, tw-animate-css, typography, forms, container-queries), the CSS entry file(s) and every non-utility global rule in them, and ${groundTruth ? `confirm the compiled ground truth at ${groundTruth} matches this build` : 'how to produce the compiled ground-truth CSS (build command and output path)'}.`,
  },
  {
    key: 'components',
    prompt: `AREA: components. Determine the component library (shadcn on Radix / shadcn on Base UI / Radix / Base UI / Headless UI / React Aria / Ark / Kobalte / Bits / Reka / none), the vendored component directory, every data-*/aria-* state attribute those components emit that utilities target (grep for data-[ and aria- variants), data-slot usage, the class-merge / variant helpers (cn, twMerge, cva, tv, clsx) and every place they merge a caller className into a base, shared icon / leaf components and how they take sizes, and animation utilities in use (animate-in, data-[state=open]:…).`,
  },
  {
    key: 'overrides',
    prompt: `AREA: cascade overrides. Read every global stylesheet and every <style> block. List (1) rules outside @layer utilities that target elements also styled by utilities (e.g. [data-slot=button] transitions, body font, resets beyond preflight) — for each: selector, declarations, the elements it hits, and whether it beats the utility (specificity and layer order); (2) parent → child utilities in use (divide-*, space-*, *:…, [&>…], [&_svg]…) with the files that use them; (3) group-*/peer-*/in-*/has-* variants and whether their ancestor/sibling actually exists at every call site; (4) !important utilities. A rule counts as an override only if the compiled ground truth shows the utility reading what it sets (a rule that assigns a custom property the utility never reads is inert) — cite the compiled rule, and where a baseline capture exists, the computed value.`,
  },
  {
    key: 'gate',
    prompt: `AREA: gate. From package.json scripts, lockfile, and CI config determine the package manager and exact commands for: format, lint, typecheck (or n/a), unit tests, build, and the single full gate command. Determine how existing tests assert styling (class-string greps, DOM snapshots, testing-library queries by class) and list every test file that would break when class strings disappear.`,
  },
  {
    key: 'pages',
    prompt: `AREA: pages and states. Enumerate every route / page / entry HTML the UI renders, how each is reached (URL, hash, query, extension page), the interactive states worth capturing (dialogs, menus, selects open, toggles on, armed confirmations, error states, loading states), responsive breakpoints in use (grep for sm:/md:/lg:/@container), whether the app needs a logged-in or seeded state and how to seed it (localStorage keys, cookies, fixtures, mock server, a stubbed preload bridge), what marks a page as still loading (fallback selectors), and any wall-clock UI (auto-dismiss, countdowns). Propose the parity host for ${skill}/scripts/parity.ts (--serve <build dir> | --url <dev/prod server> | --cdp for Electron/extension) and a draft scenario list.`,
  },
]

const discoverPrompt = (a) => `You are the intake reader for a Tailwind → StyleX migration of the project at ${repo}. Read the repository (package.json, config files, CSS entry files, components, tests) — do not edit anything.${baseRef ? ` The working tree is mid-migration: describe the PRE-migration state from \`git -C ${repo} show ${baseRef}:<file>\` wherever a file already contains StyleX, and say so in the evidence.` : ""}

${a.prompt}

Return facts as key/value pairs with the file:line evidence for each, and list what you could not determine.`

const specPrompt = (facts) => `Write the migration spec for the project at ${repo} to ${out}, filling every section of ${skill}/SPEC-TEMPLATE.md (read it first; keep its headings and tables). Use only the discovered facts below plus what you verify yourself in the repo; mark anything unknown as "TBD: <what to check>" rather than guessing. Read ${skill}/MAPPING.md so section 3–7 use its vocabulary (effective declaration, structural rule, marker, dropped rule) and ${skill}/INTEGRATION.md for the wiring section. Section 11 assigns every file that contains utility classes to a group of related files (shared primitives first, then views), each group under ~8 files, with the overrides that apply to it in its notes.

Discovered facts:
${JSON.stringify(facts, null, 2)}

Return the absolute path of the written spec and a list of TBD items.`

phase('Discover')
const found = (await parallel(AREAS.map((a) => () => agent(discoverPrompt(a), { label: `discover:${a.key}`, phase: 'Discover', schema: FACTS, model, effort })))).filter(Boolean)
log(`intake: ${found.reduce((n, f) => n + f.facts.length, 0)} facts, ${found.reduce((n, f) => n + f.unknowns.length, 0)} unknowns`)

phase('Spec')
const spec = await agent(specPrompt(found), { label: 'write-spec', phase: 'Spec', model, effort })
return { facts: found, spec }
