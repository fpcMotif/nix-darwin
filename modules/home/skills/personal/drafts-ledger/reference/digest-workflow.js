// drafts-ledger digest workflow — run with the Workflow tool:
//   Workflow({ scriptPath: "/Users/martinfan/.skillshub/drafts-ledger/reference/digest-workflow.js",
//              args: { S: "<work dir holding chunks/, items.jsonl, installed_skills.md, gh_activity.md>",
//                      manifest: <contents of chunks/manifest.json>,
//                      profile: "<one paragraph on who the reader is and what they build>",   // optional
//                      period: "July–August 2026", footer: "Source: ... Built YYYY-MM-DD." } })  // optional
// Phases: Read (haiku, one agent per chunk) → Bucket synthesis → Cross-cut (best writing, skill gaps, narrative)
//         → Verify (haiku refuters per claim) → Critic (completeness) + fix-ups.
// Output: digest.json shape consumed by `drafts-ledger render`.
export const meta = {
  name: 'drafts-ledger-digest',
  description: 'Summarize a period of Drafts link captures (GitHub, x.com, blogs, papers, videos): Haiku readers per chunk, per-bucket synthesis, best tech/AI writing, skill-gap analysis, adversarial verification, completeness critic',
  phases: [
    { title: 'Read', detail: 'Haiku reads each ~120-item chunk', model: 'haiku' },
    { title: 'Bucket synthesis', detail: 'merge chunk reads per bucket' },
    { title: 'Cross-cut', detail: 'best writing, skill gaps, two-month narrative' },
    { title: 'Verify', detail: 'Haiku refuters check URLs and claims against the data', model: 'haiku' },
    { title: 'Critic', detail: 'completeness check and fix-ups' },
  ],
}

const S = args.S
const manifest = args.manifest
const DEFAULT_PROFILE = `The reader is "f" (GitHub fpcMotif): builds native macOS apps in Swift (floodlight, a Spotlight alternative; tinycast launcher), TypeScript Chrome extensions with WXT + Effect, Next.js/Vercel marketing sites, Rust CLIs, nix-darwin dotfiles, Feishu/Lark + Outlook bridges, and AI coding-agent tooling (pi, Claude Code, Codex). Strong pure-math background (algebraic geometry, category theory, Lean), reads English, Chinese, Japanese and French. Uses Claude Code heavily with a large library of installed "skills".`

const PROFILE = args.profile || DEFAULT_PROFILE
const PERIOD = args.period || 'the window'
const FOOTER = args.footer || ''

const CHUNK_SCHEMA = {
  type: 'object',
  properties: {
    themes: { type: 'array', items: { type: 'object', properties: {
      name: { type: 'string' }, count: { type: 'integer' }, note: { type: 'string' },
      example_urls: { type: 'array', items: { type: 'string' } } }, required: ['name', 'count', 'note'] } },
    highlights: { type: 'array', items: { type: 'object', properties: {
      title: { type: 'string' }, url: { type: 'string' }, why: { type: 'string' }, kind: { type: 'string' } }, required: ['title', 'url', 'why', 'kind'] } },
    people: { type: 'array', items: { type: 'object', properties: { handle: { type: 'string' }, why: { type: 'string' } }, required: ['handle', 'why'] } },
    skills_implied: { type: 'array', items: { type: 'string' } },
    user_notes_signal: { type: 'string' },
  },
  required: ['themes', 'highlights', 'people', 'skills_implied', 'user_notes_signal'],
}

const BUCKET_SCHEMA = {
  type: 'object',
  properties: {
    overview: { type: 'string' },
    top_themes: { type: 'array', items: { type: 'object', properties: {
      name: { type: 'string' }, approx_count: { type: 'integer' }, description: { type: 'string' }, trend: { type: 'string' } }, required: ['name', 'approx_count', 'description', 'trend'] } },
    top_highlights: { type: 'array', items: { type: 'object', properties: {
      title: { type: 'string' }, url: { type: 'string' }, why: { type: 'string' }, kind: { type: 'string' } }, required: ['title', 'url', 'why', 'kind'] } },
    key_people: { type: 'array', items: { type: 'object', properties: { handle: { type: 'string' }, why: { type: 'string' } }, required: ['handle', 'why'] } },
    skills_implied: { type: 'array', items: { type: 'string' } },
    july_vs_august: { type: 'string' },
  },
  required: ['overview', 'top_themes', 'top_highlights', 'key_people', 'skills_implied', 'july_vs_august'],
}

const BEST_SCHEMA = {
  type: 'object',
  properties: {
    groups: { type: 'array', items: { type: 'object', properties: {
      topic: { type: 'string' },
      pieces: { type: 'array', items: { type: 'object', properties: {
        title: { type: 'string' }, url: { type: 'string' }, source: { type: 'string' }, why: { type: 'string' }, must_read: { type: 'boolean' } },
        required: ['title', 'url', 'source', 'why', 'must_read'] } } }, required: ['topic', 'pieces'] } },
    sources_to_follow: { type: 'array', items: { type: 'object', properties: { name: { type: 'string' }, url: { type: 'string' }, why: { type: 'string' } }, required: ['name', 'why'] } },
    method_note: { type: 'string' },
  },
  required: ['groups', 'sources_to_follow', 'method_note'],
}

const GAP_SCHEMA = {
  type: 'object',
  properties: {
    install_or_adopt: { type: 'array', items: { type: 'object', properties: {
      name: { type: 'string' }, url: { type: 'string' }, what: { type: 'string' }, why_for_f: { type: 'string' }, evidence: { type: 'string' }, priority: { type: 'string' } },
      required: ['name', 'url', 'what', 'why_for_f', 'evidence', 'priority'] } },
    skills_to_write: { type: 'array', items: { type: 'object', properties: {
      name: { type: 'string' }, what: { type: 'string' }, why_for_f: { type: 'string' }, seed_urls: { type: 'array', items: { type: 'string' } }, priority: { type: 'string' } },
      required: ['name', 'what', 'why_for_f', 'seed_urls', 'priority'] } },
    knowledge_gaps: { type: 'array', items: { type: 'object', properties: {
      topic: { type: 'string' }, evidence: { type: 'string' }, why_gap: { type: 'string' }, first_step: { type: 'string' }, priority: { type: 'string' } },
      required: ['topic', 'evidence', 'why_gap', 'first_step', 'priority'] } },
    workflow_gaps: { type: 'array', items: { type: 'object', properties: { observation: { type: 'string' }, fix: { type: 'string' } }, required: ['observation', 'fix'] } },
    already_covered: { type: 'array', items: { type: 'string' } },
  },
  required: ['install_or_adopt', 'skills_to_write', 'knowledge_gaps', 'workflow_gaps', 'already_covered'],
}

const VERDICT = {
  type: 'object',
  properties: { ok: { type: 'boolean' }, reason: { type: 'string' }, corrected_title: { type: 'string' }, corrected_url: { type: 'string' } },
  required: ['ok', 'reason'],
}

const CRITIC_SCHEMA = {
  type: 'object',
  properties: { missing: { type: 'array', items: { type: 'object', properties: { issue: { type: 'string' }, severity: { type: 'string' }, fix_prompt: { type: 'string' } }, required: ['issue', 'severity', 'fix_prompt'] } }, overall: { type: 'string' } },
  required: ['missing', 'overall'],
}

const BUCKET_GUIDE = {
  github: 'GitHub repos and files the user saved. Metadata shows [stars language] description topics. Judge by what the repo enables for f, not stars alone. Kinds: repo, skill, tool, library, reference.',
  x: 'x.com posts the user saved. Metadata shows @author (name; bio) [likes]: tweet text || QT quoted text. Judge by substance of the post (ideas, threads, announcements), not engagement. Kinds: thread, announcement, take, tutorial, tool.',
  web: 'Web articles, blog posts, docs, product sites, newsletters. Metadata shows page title — description. This is the bucket that matters most for "excellent tech and AI writing": pick substantive essays and technical posts over product landing pages. Kinds: essay, technical-post, docs, product, newsletter, news, paper-page, other.',
  arxiv: 'arXiv papers. Metadata shows [category published] title — abstract. Kinds: paper.',
  youtube: 'YouTube videos/playlists. Metadata shows channel — title. Kinds: lecture, talk, tutorial, music, other. Music and entertainment exist; count them but do not highlight them.',
  notes: 'The user\'s own text-only drafts (no URL): thoughts, todo fragments, snippets. Summarize what they reveal about current projects, worries and intentions. Highlights here = the most telling notes; use url "(no url)" and quote the first words as title.',
}

const buckets = [...new Set(manifest.map(m => m.bucket))].map(b => ({ bucket: b, chunks: manifest.filter(m => m.bucket === b) }))
log(`${manifest.length} chunks across ${buckets.length} buckets: ${buckets.map(b => `${b.bucket}=${b.chunks.length}`).join(', ')}`)

function chunkPrompt(m) {
  return `You are one of many readers digesting a developer's saved links. Read the file ${m.path} with Bash (cat it in full; it is ~${m.n} lines). It lists ${m.n} items saved to the Drafts app between ${m.from} and ${m.to}, bucket "${m.bucket}". Line format: date | url | metadata | NOTE: text the user wrote when saving | dup×N (saved more than once) | tags.
${BUCKET_GUIDE[m.bucket]}

${PROFILE}

Return StructuredOutput:
- themes: cluster EVERY item into 5-12 themes; count = number of items in that theme (counts should sum to roughly ${m.n}); note = 1-2 sentences of what the cluster is, naming 2-4 concrete items; example_urls = 2-4 urls copied exactly from the file.
- highlights: the 8-15 most valuable items for f. Prefer substantive technical/AI writing, unusually useful repos, high-signal posts, things f saved twice (dup×N) or annotated with a NOTE. url MUST be copied character-for-character from the file (including ?s=12 etc). why = one sentence on what makes it excellent or useful to f specifically.
- people: authors/accounts/channels/blogs appearing 2+ times or clearly important, with why.
- skills_implied: 5-12 short phrases naming concrete skills, tools, techniques or knowledge the user seems to be learning, evaluating, or would need to act on these links (e.g. "Effect-TS for Cloudflare Workers", "writing Claude Code skills", "Metal shaders for UI").
- user_notes_signal: 2-4 sentences: what do the NOTE fields and dup×N items reveal about intent (what is f trying to build or decide)?
Never invent URLs or titles. If a line has no metadata, judge from the URL slug only and say so in why.`
}

function bucketPrompt(b, reads) {
  return `You are synthesizing ${reads.length} reader reports covering ${b.chunks.reduce((s, c) => s + c.n, 0)} links in bucket "${b.bucket}" (${BUCKET_GUIDE[b.bucket]}) saved by a developer between ${b.chunks[0].from} and ${b.chunks[b.chunks.length - 1].to}. Reports are in chronological order.

${PROFILE}

Reader reports (JSON):
${JSON.stringify(reads)}

The raw chunk files are at ${b.chunks.map(c => c.path).join(', ')} — grep them (rg) when you need to confirm a URL or count.

Return StructuredOutput:
- overview: 250-450 words. What this bucket says about f's two months. Be concrete: name repos/authors/posts. No filler.
- top_themes: 6-12 themes merged across all reports, ranked by approx_count (sum matching reader counts). description = 2-3 sentences naming concrete items. trend = how it moved from early July to late August (rising, fading, spike on dates, steady).
- top_highlights: 15-25 best items across the whole bucket, deduplicated. Copy url exactly from reader reports. why = one sentence, specific.
- key_people: 8-15 recurring or important authors/accounts/channels with why.
- skills_implied: 8-15 phrases, merged and deduplicated, most-evidenced first.
- july_vs_august: 3-6 sentences on what shifted between the start and the end of the window (field name is historical).`
}

const bucketResults = await pipeline(
  buckets,
  b => parallel(b.chunks.map(m => () =>
    agent(chunkPrompt(m), { label: `read:${m.id}`, phase: 'Read', schema: CHUNK_SCHEMA, model: 'haiku', effort: 'medium' })
      .then(r => r ? { ...r, chunk: m.id, from: m.from, to: m.to, n: m.n } : null)))
    .then(rs => rs.filter(Boolean)),
  (reads, b) => {
    log(`bucket ${b.bucket}: ${reads.length}/${b.chunks.length} chunk reads succeeded`)
    if (!reads.length) return null
    return agent(bucketPrompt(b, reads), { label: `synth:${b.bucket}`, phase: 'Bucket synthesis', schema: BUCKET_SCHEMA, effort: 'high' })
      .then(r => r ? { bucket: b.bucket, items: b.chunks.reduce((s, c) => s + c.n, 0), chunks_read: reads.length, report: r, reads } : null)
  }
)
const bucketsDone = bucketResults.filter(Boolean)
log(`bucket syntheses complete: ${bucketsDone.map(b => b.bucket).join(', ')}`)

const reportsOnly = Object.fromEntries(bucketsDone.map(b => [b.bucket, { items: b.items, ...b.report }]))
const reportsJSON = JSON.stringify(reportsOnly)
const chunkPaths = manifest.map(m => m.path).join(' ')

const bestPrompt = `Curate "the excellent tech and AI writing" a developer saved over ${PERIOD}. You have per-bucket synthesized reports (JSON below) and the raw chunk files; the web bucket files (${manifest.filter(m => m.bucket === 'web').map(m => m.path).join(' ')}) and x bucket files (${manifest.filter(m => m.bucket === 'x').map(m => m.path).join(' ')}) hold title/description/tweet text per line — rg them freely to find and confirm candidates beyond what the reports surfaced. Also consider substack and github READMEs when they are genuinely essays.

${PROFILE}

Bucket reports:
${reportsJSON}

Rules: prefer essays, technical deep-dives, engineering blog posts, long x.com threads with real ideas, and lecture series over product pages, launch tweets and news. Every url must exist verbatim in a chunk file (confirm with rg -F on the url without its query string). Return StructuredOutput: groups = 6-10 topics (e.g. "AI coding agents and harness design", "Systems and databases", "Frontend craft and design engineering", "ML theory and RL", "Math", "Apple platform", "Careers and industry"), each with 3-8 pieces; mark must_read on the ~10 best overall; source = author or site; why = one specific sentence. sources_to_follow = 10-15 blogs/newsletters/accounts/channels that produced the best material, with why. method_note = 2 sentences on how you chose.`

const gapPrompt = `Find the skills a developer needs but is missing, using two months of their saved links. Read these files with Bash first: ${S}/installed_skills.md (what Claude Code skills, plugins and MCP servers f already has) and ${S}/gh_activity.md (what f actually built and pushed in the window). Then use the bucket reports below. Raw chunk files (${chunkPaths}) can be grepped with rg to confirm any URL or count.

${PROFILE}

Bucket reports:
${reportsJSON}

Produce StructuredOutput with four lists, each ranked by priority (high/medium/low) and each item concrete and evidenced:
1. install_or_adopt: specific Claude Code skills, plugins, MCP servers, agent tools or CLIs that appear in f's saved links (repos, posts) and are NOT already in installed_skills.md. url must be a link that exists verbatim in a chunk file. what = what it does; why_for_f = tie to f's actual repos/work; evidence = how many times / with what NOTE f saved it. 8-15 items. Do not list things already installed (check names in installed_skills.md carefully; list those under already_covered instead).
2. skills_to_write: 5-10 Claude Code skills f should author themselves because their captures and repos show a recurring need with no installed equivalent (e.g. a Swift/AppKit skill for floodlight, a WXT+Effect Chrome-extension skill, a Feishu/Lark Bitable skill, a nix-darwin skill). seed_urls = 2-5 links from the captures to build it from.
3. knowledge_gaps: 6-12 technical topics f keeps saving (evidence = counts/themes from reports) but does not appear to use in gh_activity.md, i.e. learning intent without practice; why_gap and a first_step that uses one of the saved links.
4. workflow_gaps: observations from capture behaviour itself (e.g. thousands of links, only ~30 tagged, duplicates, reading vs building ratio, x.com vs long-form ratio) with a concrete fix each. 4-8 items.
already_covered: skills f already has that the captures keep re-discovering (name the installed skill and the captured link).`

const narrativePrompt = `Write the two-month narrative of what a developer was chasing, from their saved links. Use the bucket reports (JSON) below; grep raw chunk files (${chunkPaths}) with rg if you need to confirm a specific item or date. Also read ${S}/gh_activity.md to contrast what f saved with what f shipped.

${PROFILE}

Bucket reports:
${reportsJSON}

Return plain markdown (no StructuredOutput), 600-900 words, with these sections: "The five obsessions" (each with counts from the reports and 2-3 named items), "early vs late in the window" (what rose, what faded, spikes with dates), "Saved vs shipped" (compare captures with gh_activity.md repos), "Signals in the user's own notes" (from the notes bucket and NOTE fields), "One-paragraph verdict". Be specific and unsentimental; name items and people. No headers other than these five.`

const [best, gaps, narrative] = await parallel([
  () => agent(bestPrompt, { label: 'curate:best-writing', phase: 'Cross-cut', schema: BEST_SCHEMA, effort: 'high' }),
  () => agent(gapPrompt, { label: 'analyze:skill-gaps', phase: 'Cross-cut', schema: GAP_SCHEMA, effort: 'xhigh' }),
  () => agent(narrativePrompt, { label: 'write:narrative', phase: 'Cross-cut', effort: 'high' }),
])
log(`cross-cut done: best=${best ? best.groups.reduce((s, g) => s + g.pieces.length, 0) : 0} pieces, gaps=${gaps ? gaps.install_or_adopt.length + gaps.skills_to_write.length + gaps.knowledge_gaps.length : 0} items`)

function verifyUrlPrompt(kind, title, url, claim) {
  const bare = (url || '').split('?')[0].split('#')[0]
  return `Adversarially verify one ${kind} from a digest of a user's saved links. Claim: title="${title}", url="${url}", why="${claim}".
Steps with Bash: (1) rg -F -m 3 "${bare}" ${S}/items.jsonl — the url (ignoring query string) must appear; if it does not, try rg -F on the last path segment; (2) rg -F -m 2 "${bare}" ${S}/chunks/ to read the metadata line (title/description/tweet text). Decide: ok=true only if the url exists in the user's captures AND the title/why are consistent with the metadata line (a paraphrased title is fine; a different article, invented author, or invented content is not). If the url is not found at all, ok=false. If a small correction fixes it (title wording, url variant that does exist), set corrected_title/corrected_url and ok=true. Default to ok=false when uncertain. reason = one sentence quoting the metadata you saw.`
}
function verifyGapPrompt(item) {
  return `Adversarially verify one "install or adopt" recommendation from a skill-gap analysis. Recommendation: name="${item.name}", url="${item.url}", what="${item.what}", evidence="${item.evidence}".
Steps with Bash: (1) rg -F -m 3 "${(item.url || '').split('?')[0]}" ${S}/items.jsonl — must exist in the user's captures; (2) rg -i -F "${item.name.split(/[\s(:/]/)[0]}" ${S}/installed_skills.md — if the same tool/skill is already installed, ok=false with reason "already installed"; (3) rg -F -m 2 "${(item.url || '').split('?')[0]}" ${S}/chunks/ to check the description matches "what". ok=true only if the url is in the captures, it is not already installed, and "what" matches the metadata. Default ok=false if uncertain. reason = one sentence citing what you saw.`
}

const bestPieces = best ? best.groups.flatMap(g => g.pieces.map(p => ({ ...p, topic: g.topic }))) : []
const bucketHighlights = bucketsDone.flatMap(b => (b.report.top_highlights || []).slice(0, 12).map(h => ({ ...h, bucket: b.bucket })))
log(`verifying ${bestPieces.length} curated pieces, ${bucketHighlights.length} bucket highlights, ${gaps ? gaps.install_or_adopt.length : 0} install recommendations`)

const [verifiedBest, verifiedHighlights, verifiedGaps] = await parallel([
  () => parallel(bestPieces.map((p, i) => () =>
    agent(verifyUrlPrompt('curated article', p.title, p.url, p.why), { label: `verify:best:${i}`, phase: 'Verify', schema: VERDICT, model: 'haiku', effort: 'low' })
      .then(v => ({ ...p, verdict: v })))),
  () => parallel(bucketHighlights.map((h, i) => () =>
    agent(verifyUrlPrompt(`${h.bucket} highlight`, h.title, h.url, h.why), { label: `verify:${h.bucket}:${i}`, phase: 'Verify', schema: VERDICT, model: 'haiku', effort: 'low' })
      .then(v => ({ ...h, verdict: v })))),
  () => parallel((gaps ? gaps.install_or_adopt : []).map((g, i) => () =>
    agent(verifyGapPrompt(g), { label: `verify:gap:${i}`, phase: 'Verify', schema: VERDICT, model: 'haiku', effort: 'low' })
      .then(v => ({ ...g, verdict: v })))),
])

function keep(list) {
  const kept = [], dropped = []
  for (const x of list.filter(Boolean)) {
    const v = x.verdict
    if (v && v.ok) kept.push({ ...x, title: v.corrected_title || x.title, url: v.corrected_url || x.url, verdict: undefined })
    else dropped.push({ title: x.title || x.name, url: x.url, reason: v ? v.reason : 'verifier died' })
  }
  return { kept, dropped }
}
const bestV = keep(verifiedBest), highV = keep(verifiedHighlights), gapV = keep(verifiedGaps)
log(`verify: best kept ${bestV.kept.length}/${bestPieces.length}; highlights kept ${highV.kept.length}/${bucketHighlights.length}; install recs kept ${gapV.kept.length}/${gaps ? gaps.install_or_adopt.length : 0}`)

const draftDigest = {
  buckets: Object.fromEntries(bucketsDone.map(b => [b.bucket, { items: b.items, chunks_read: b.chunks_read, overview: b.report.overview, top_themes: b.report.top_themes, key_people: b.report.key_people, skills_implied: b.report.skills_implied, july_vs_august: b.report.july_vs_august, top_highlights: highV.kept.filter(h => h.bucket === b.bucket) }])),
  best_writing: best ? { groups: best.groups.map(g => ({ topic: g.topic, pieces: bestV.kept.filter(p => p.topic === g.topic) })).filter(g => g.pieces.length), sources_to_follow: best.sources_to_follow, method_note: best.method_note } : null,
  skill_gaps: gaps ? { ...gaps, install_or_adopt: gapV.kept } : null,
  narrative,
  dropped_by_verification: { best: bestV.dropped, highlights: highV.dropped, install: gapV.dropped },
}

const critic = await agent(`You are the completeness critic for a digest of a developer's two months of saved links (6,719 items: web 2,482, youtube 1,585, x 1,242, github 1,042, arxiv 319, notes 50). The user asked for: a summary of the recent two months of GitHub and x.com captures, especially the excellent tech and AI blog writing, and the skills they need but are missing. The digest so far (JSON):
${JSON.stringify(draftDigest)}

Raw data you can grep with rg: chunk files ${chunkPaths}; installed skills ${S}/installed_skills.md; the user's own GitHub activity ${S}/gh_activity.md.
Ask: what is missing or wrong? A bucket the user asked about that is thin; a big theme in the chunk files that no report mentions (spot-check by grepping for recurring domains, authors, repos); highlights that are product pages rather than writing; skill-gap items that are vague or not tied to f's repos; anything verification dropped that was actually important and should be re-added with the correct URL; math/Japanese/Chinese-language material ignored. Return StructuredOutput: missing = up to 6 issues, each with severity (high/medium/low) and a fix_prompt that a fresh agent could execute against the same files to produce an addendum (self-contained, names the files and what to output). overall = 3 sentences.`, { label: 'critic:completeness', phase: 'Critic', schema: CRITIC_SCHEMA, effort: 'high' })

const fixes = critic ? critic.missing.filter(m => m.severity === 'high' || m.severity === 'medium').slice(0, 4) : []
log(`critic found ${critic ? critic.missing.length : 0} issues; running ${fixes.length} fix-ups`)
const addenda = await parallel(fixes.map((f, i) => () =>
  agent(`${f.fix_prompt}

Context: ${PROFILE}
Files: chunk files ${chunkPaths}; ${S}/installed_skills.md; ${S}/gh_activity.md; ${S}/items.jsonl. Every URL you cite must be confirmed with rg -F against ${S}/items.jsonl. Return plain markdown, 150-400 words, titled with the issue: "${f.issue}".`, { label: `fix:${i}`, phase: 'Critic', effort: 'high' })
    .then(r => r ? { issue: f.issue, severity: f.severity, addendum: r } : null)))

return { ...draftDigest, critic, addenda: addenda.filter(Boolean), footer: FOOTER, stats: { chunks: manifest.length, buckets_done: bucketsDone.map(b => `${b.bucket}:${b.chunks_read}/${b.chunks ? b.chunks.length : '?'}`) } }
