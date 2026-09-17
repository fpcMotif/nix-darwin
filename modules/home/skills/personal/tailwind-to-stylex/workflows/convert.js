export const meta = {
  name: 'tailwind-to-stylex-convert',
  description: 'Convert disjoint file groups from Tailwind utilities to StyleX, one agent per group, against the project spec and the compiled ground-truth CSS',
  phases: [{ title: 'Convert', detail: 'one agent per file group, editing in place' }],
}

// args: {
//   repo?, spec?, groundTruth?,
//   commands: { format?, lint?, typecheck?, test? },
//   model?, effort?,
//   groups: [{ key, files, tests?, notes? }]
// }
import path from 'node:path'

const repo = path.resolve(args?.repo || process.cwd())
const spec = path.resolve(args?.spec || path.join(repo, 'SPEC.md'))
const groundTruth = path.resolve(args?.groundTruth || path.join(repo, '.parity', 'ground-truth.css'))
const groups = args?.groups || []
const commands = args?.commands || {}
const model = args?.model || 'sonnet'
const effort = args?.effort || 'high'

const REPORT = {
  type: 'object',
  properties: {
    group: { type: 'string' },
    files: { type: 'array', items: { type: 'string' } },
    dropped: {
      type: 'array',
      items: {
        type: 'object',
        properties: { file: { type: 'string' }, utility: { type: 'string' }, reason: { type: 'string' } },
        required: ['file', 'utility', 'reason'],
      },
    },
    notes: { type: 'string' },
    uncertainties: { type: 'array', items: { type: 'string' } },
    gate: {
      type: 'object',
      properties: {
        format: { type: 'string', enum: ['clean', 'failed', 'n/a'] },
        lint: { type: 'string', enum: ['clean', 'failed', 'n/a'] },
        typecheck: { type: 'string', enum: ['clean', 'failed', 'n/a'] },
        tests: { type: 'string', enum: ['pass', 'failed', 'n/a'] },
      },
      required: ['format', 'lint', 'typecheck', 'tests'],
    },
  },
  required: ['group', 'files', 'dropped', 'notes', 'uncertainties', 'gate'],
}

const gateLines = () =>
  ['format', 'lint', 'typecheck', 'test']
    .map((k) => (commands[k] ? `- ${k}: \`${commands[k]}\` (append your files where it takes a file list)` : `- ${k}: not configured for this project → report n/a`))
    .join('\n')

const prompt = (g) => `You are converting one file group of a Tailwind → StyleX migration whose hard requirement is EXACT computed-style parity with the original in every state (default, hover, focus-visible, active, disabled, every data-*/aria-* state the component library emits, both colour schemes if the project has them, every viewport).

Repo: ${repo}. Spec: ${spec} — read it fully before editing; it fixes the stack (framework, StyleX call — props or attrs — and the style-forwarding prop name), the Tailwind major version and dark-mode strategy, the value tables, the cascade rules (utility order, global overrides, the project's class-merge / variant helpers if any), the descendant-marker and structural-attribute conventions, and the component API.
Ground truth (the CSS Tailwind compiled for the baseline build): ${groundTruth} — grep it for EVERY utility you convert; write the value it emits, never one from memory.
Infrastructure already migrated (read, do not edit): the token / marker *.stylex.* files, the global stylesheet, and any shared leaf components named in the spec.

Your files (you own these and nothing else): ${g.files.join(', ')}
${g.tests && g.tests.length ? `Tests you own (update their styling assertions to the StyleX objects and keep them passing): ${g.tests.join(', ')}` : 'You own no tests.'}
${g.notes ? `Group notes: ${g.notes}` : ''}

Method, per element: list its utilities → look each up in the ground truth → resolve the effective declaration (stylesheet order, merge-helper removals at the call site and inside variant definitions, global rules that used to beat utilities) → write that declaration once. Attribute and pseudo keys mirror the original variants exactly. Every rule you drop gets a \`// dropped: <utility> — <why>\` comment at the site. Leave the DOM identical: no added, removed, or reordered elements; every attribute other than class preserved; inline styles untouched.

Done when: no utility-class strings, class-merge / variant-helper imports, or class props remain in your files (per the spec's component API); the project gate below is clean for your files; your tests pass. Do not run the build or the whole test suite; do not edit files you do not own.

Project gate:
${gateLines()}

Report per the schema: every dropped rule with its reason, every value you were unsure of as an uncertainty (property, element, the two candidates), and the gate results.`

phase('Convert')
const results = await parallel(
  groups.map((g) => () =>
    agent(prompt(g), { label: `convert:${g.key}`, phase: 'Convert', schema: REPORT, model, effort }),
  ),
)
const done = results.filter(Boolean)
log(`convert: ${done.length}/${groups.length} groups reported; ${done.reduce((n, r) => n + r.dropped.length, 0)} dropped rules; ${done.reduce((n, r) => n + r.uncertainties.length, 0)} uncertainties`)
return { groups: done, failed: groups.filter((g) => !done.some((r) => r.group === g.key)).map((g) => g.key) }
