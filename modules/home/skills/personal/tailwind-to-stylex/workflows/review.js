export const meta = {
  name: 'tailwind-to-stylex-review',
  description: 'Review every migrated file against its original and the ground-truth CSS (two lenses), refute each finding twice, fix confirmed findings',
  phases: [
    { title: 'Review', detail: 'two independent lenses per file: value exactness, cascade/precedence' },
    { title: 'Verify', detail: 'two skeptics re-derive each finding from the ground truth' },
    { title: 'Fix', detail: 'one agent per file with confirmed findings' },
  ],
}

// args: {
//   repo?, spec?, groundTruth?, baseRef?,
//   files,
//   commands: { format?, lint?, typecheck? },
//   harnessDiffs?,
//   extraContext?, model?, effort?
// }
import path from 'node:path'

const repo = path.resolve(args?.repo || process.cwd())
const spec = path.resolve(args?.spec || path.join(repo, 'SPEC.md'))
const groundTruth = path.resolve(args?.groundTruth || path.join(repo, '.parity', 'ground-truth.css'))
const baseRef = args?.baseRef || 'HEAD'
const files = args?.files || []
const commands = args?.commands || {}
const model = args?.model || 'sonnet'
const effort = args?.effort || 'high'
const harnessDiffs = args?.harnessDiffs ? path.resolve(args.harnessDiffs) : null
const extraContext = args?.extraContext || ''

const LENSES = [
  {
    key: 'values',
    prompt: `LENS: value exactness. For EVERY element in the original file, enumerate its utilities, look each one up in the ground-truth CSS, and check the StyleX declaration carries exactly the same property and value (units, calc strings, colour functions and opacity modifiers, multi-layer box-shadows, transition-property lists, the compiled rounded-full value for this Tailwind major, line-heights, keyframe recipes, pseudo-element content). Check every descendant-marker application and every shared leaf component's style props match the spec.`,
  },
  {
    key: 'cascade',
    prompt: `LENS: cascade and precedence. Check (a) class-merge / variant-helper conflicts (tailwind-merge, cva, tailwind-variants, or whatever the spec names — skip if none) were resolved per the spec: removed base utilities leave the right properties unset/null, especially line-height when an arbitrary text size replaces a named one, and width/height/rounded/min-w/gap replacements; (b) global rules that used to outrank utilities are restated on every affected element and nowhere else; (c) order-dependent utility pairs resolve by stylesheet order (leading-* beats text-*'s line-height; pl-*/pr-* beat px-*); (d) hover: nesting matches the Tailwind major (v4: under @media (hover: hover); v3: bare), dark: nesting matches the spec's dark-mode strategy (media query, or the theme applied for the class/attribute selector), dark placed last, with focus/aria variants restated inside dark blocks where the light variant used to win; (e) attribute/pseudo keys mirror the original variants and the component library's attribute vocabulary exactly; (f) structural data attributes were added wherever parent→child utilities were removed; (g) every dropped rule is genuinely dead at all call sites (grep the repo) and every kept rule is still expressed; (h) the DOM is unchanged: no added/removed/reordered elements, every attribute other than class preserved, inline styles untouched; (i) for server-rendered frameworks, nothing in the file makes the server and client class/style output differ (no render-time branching on window, matchMedia, or storage).`,
  },
]

const FINDINGS = {
  type: 'object',
  properties: {
    file: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          line: { type: 'integer' },
          element: { type: 'string' },
          property: { type: 'string' },
          expected: { type: 'string' },
          actual: { type: 'string' },
          evidence: { type: 'string' },
          severity: { type: 'string', enum: ['visible', 'state-only', 'dead-code'] },
        },
        required: ['line', 'element', 'property', 'expected', 'actual', 'evidence', 'severity'],
      },
    },
  },
  required: ['file', 'findings'],
}

const VERDICT = {
  type: 'object',
  properties: { real: { type: 'boolean' }, reason: { type: 'string' }, correctedExpected: { type: 'string' } },
  required: ['real', 'reason'],
}

const FIX_REPORT = {
  type: 'object',
  properties: { file: { type: 'string' }, applied: { type: 'array', items: { type: 'string' } }, skipped: { type: 'array', items: { type: 'string' } } },
  required: ['file', 'applied', 'skipped'],
}

const context = (file) => `Repo: ${repo}. Original: \`git -C ${repo} show ${baseRef}:${file}\`. Migrated: ${repo}/${file}. Spec: ${spec} (read it fully first — it names the stack, Tailwind major, dark-mode strategy, merge helpers, and component library). Ground truth (the CSS Tailwind compiled): ${groundTruth} — grep it for every utility; never trust memory for compiled Tailwind values, v3 and v4 differ.
${extraContext}`

const reviewPrompt = (file, lens) => `You are reviewing one file of a Tailwind → StyleX migration whose hard requirement is EXACT computed-style parity with the original in every state (default, hover, focus-visible, active, disabled, the component library's data-*/aria-* states, both colour schemes if the project has them).

${context(file)}
${harnessDiffs ? `A computed-style harness already found these differences (JSON): ${harnessDiffs} — read it, and for any entry touching this file, explain the cause and include it as a finding.` : ''}

${lens.prompt}

Be adversarial and concrete: report only discrepancies you can back with a ground-truth citation (quote the compiled rule) — no style suggestions, no refactors. Each finding: the migrated line, the element, the CSS property, the exact expected value (from the ground truth, after cascade/merge resolution), the actual value in the migrated file, and the evidence. Severity: 'visible' if it changes the rendered default state, 'state-only' if it only affects hover/focus/active/disabled/data-* states, 'dead-code' if it only concerns rules no call site can reach. Return an empty findings list if the file is exact.`

const verifyPrompt = (file, f) => `Independently verify (try to REFUTE) this claimed Tailwind → StyleX discrepancy.
${context(file)}

Claim: line ${f.line}, element "${f.element}", property ${f.property}: expected "${f.expected}", actual "${f.actual}". Evidence given: ${f.evidence}

Derive the true effective value yourself from the ground truth (cascade order, merge-helper removals, global overrides per the spec, structural rules that intentionally moved to the global stylesheet). real=true only if the migrated file would produce a different computed style than the original in some reachable state; if the reviewer's "expected" was itself wrong but a discrepancy still exists, set real=true and put the right value in correctedExpected. Default to real=false when the claim does not hold up.`

const gate = (file) =>
  ['format', 'lint', 'typecheck']
    .filter((k) => commands[k])
    .map((k) => `${commands[k]} ${file}`)
    .join('; ')

const fixPrompt = (file, findings) => `Apply these CONFIRMED fixes to ${repo}/${file} (a Tailwind → StyleX migration that must keep exact computed-style parity). Spec: ${spec}. Ground truth CSS: ${groundTruth}. Do not change anything else (no refactors, no DOM changes, no other files). ${gate(file) ? `After editing run: ${gate(file)} (must be clean for this file).` : ''} Do not run the build or the full test suite.

Findings (expected values are already verified):
${findings.map((f, i) => `${i + 1}. line ${f.line} — ${f.element} — ${f.property}: expected "${f.expected}" (actual "${f.actual}"). ${f.reason || ''}`).join('\n')}

Report what you applied and anything you skipped (with why).`

const base = (file) => file.split('/').pop()
const key = (file, f) => `${file}|${f.line}|${f.property}|${f.element}`.toLowerCase()

phase('Review')
const perFile = await parallel(
  files.map((file) => () =>
    parallel(LENSES.map((lens) => () => agent(reviewPrompt(file, lens), { label: `review:${lens.key}:${base(file)}`, phase: 'Review', schema: FINDINGS, model, effort }))).then((lensResults) => {
      const seen = new Map()
      for (const r of lensResults.filter(Boolean)) for (const f of r.findings) if (!seen.has(key(file, f))) seen.set(key(file, f), f)
      return { file, findings: [...seen.values()] }
    }),
  ),
)
log(`review: ${perFile.filter(Boolean).reduce((n, r) => n + r.findings.length, 0)} raw findings across ${files.length} files`)

phase('Verify')
const verified = await parallel(
  perFile.filter(Boolean).map((r) => () =>
    parallel(r.findings.map((f) => () =>
      parallel([0, 1].map((i) => () => agent(verifyPrompt(r.file, f), { label: `verify${i}:${base(r.file)}:${f.property}`, phase: 'Verify', schema: VERDICT, model, effort }))).then((votes) => {
        const v = votes.filter(Boolean)
        const real = v.length > 0 && v.every((x) => x.real)
        const corrected = v.find((x) => x.correctedExpected)
        return { ...f, real, reason: v.map((x) => x.reason).join(' | '), expected: corrected && corrected.correctedExpected ? corrected.correctedExpected : f.expected }
      }),
    )).then((fs) => ({ file: r.file, confirmed: fs.filter((f) => f.real), rejected: fs.filter((f) => !f.real) })),
  ),
)
log(`verify: ${verified.filter(Boolean).reduce((n, r) => n + r.confirmed.length, 0)} confirmed findings`)

phase('Fix')
const fixes = await parallel(
  verified.filter(Boolean).filter((r) => r.confirmed.length > 0).map((r) => () =>
    agent(fixPrompt(r.file, r.confirmed), { label: `fix:${base(r.file)}`, phase: 'Fix', schema: FIX_REPORT, model, effort }),
  ),
)
return { reviewed: perFile.filter(Boolean), verified: verified.filter(Boolean), fixes: fixes.filter(Boolean) }
