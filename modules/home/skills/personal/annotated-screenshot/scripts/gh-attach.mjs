#!/usr/bin/env bun
// gh-attach — host local images on a dedicated git branch and print (or post) the
// markdown that embeds them in a GitHub issue / PR.
//
//   bun gh-attach.mjs shot1.png shot2.png [--repo owner/name] [--branch assets/<slug>]
//                     [--dir docs/assets/<slug>] [--caption "text" ...] [--issue N | --pr N]
//                     [--title "## heading"] [--dry-run]
//
// Uses a temporary worktree, so the caller's working tree and branch are untouched.
// Requires: git remote `origin` with push access, `gh` authenticated.
import { execSync } from 'node:child_process'
import { copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { basename, join, resolve } from 'node:path'

const args = process.argv.slice(2)
const files = []
const opts = { caption: [] }
for (let i = 0; i < args.length; i++) {
  const a = args[i]
  if (a === '--dry-run') opts.dryRun = true
  else if (a.startsWith('--')) { const k = a.slice(2); const v = args[++i]; if (k === 'caption') opts.caption.push(v); else opts[k] = v }
  else files.push(resolve(a))
}
if (files.length === 0) { console.error('usage: gh-attach.mjs <images…> [--repo o/n] [--branch b] [--dir d] [--caption c] [--issue N | --pr N] [--dry-run]'); process.exit(2) }

const sh = (cmd, cwd) => execSync(cmd, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim()
const repoRoot = sh('git rev-parse --show-toplevel')
const repo = opts.repo ?? sh('gh repo view --json nameWithOwner -q .nameWithOwner', repoRoot)
const date = new Date().toISOString().slice(0, 10)
const slug = (opts.slug ?? basename(files[0]).replace(/\.[a-z0-9]+$/i, '')).replace(/[^a-z0-9-]+/gi, '-').toLowerCase()
const branch = opts.branch ?? `assets/${slug}`
const dir = opts.dir ?? `docs/assets/${date}-${slug}`

const wt = mkdtempSync(join(tmpdir(), 'gh-attach-'))
try {
  const remoteHas = sh(`git ls-remote --heads origin ${branch}`, repoRoot) !== ''
  if (remoteHas) { sh(`git fetch -q origin ${branch}`, repoRoot); sh(`git worktree add -q "${wt}" origin/${branch} --detach`, repoRoot); sh(`git checkout -q -B ${branch}`, wt) }
  else sh(`git worktree add -q -b ${branch} "${wt}" HEAD`, repoRoot)
  mkdirSync(join(wt, dir), { recursive: true })
  for (const f of files) copyFileSync(f, join(wt, dir, basename(f)))
  sh(`git add "${dir}"`, wt)
  const changed = sh('git status --porcelain', wt) !== ''
  if (changed && !opts.dryRun) {
    sh(`git commit -q -m "docs(assets): ${slug} (${files.length} file${files.length > 1 ? 's' : ''})"`, wt)
    sh(`git push -q -u origin ${branch}`, wt)
  }
  const urls = files.map((f) => `https://raw.githubusercontent.com/${repo}/${branch}/${dir}/${basename(f)}`)
  const md = [opts.title ?? '', ...urls.map((u, i) => `${opts.caption[i] ? `**${opts.caption[i]}**\n\n` : ''}![${basename(files[i])}](${u})`)].filter(Boolean).join('\n\n')
  console.error(`[gh-attach] ${opts.dryRun ? 'DRY RUN — would push' : changed ? 'pushed' : 'already up to date on'} ${branch} → ${dir}`)
  if (!opts.dryRun && (opts.issue || opts.pr)) {
    const tmp = join(tmpdir(), `gh-attach-${slug}.md`); writeFileSync(tmp, md)
    const kind = opts.issue ? 'issue' : 'pr'
    const url = sh(`gh ${kind} comment ${opts.issue ?? opts.pr} --repo ${repo} --body-file "${tmp}"`, repoRoot)
    console.error(`[gh-attach] commented on ${kind} #${opts.issue ?? opts.pr}: ${url}`)
  }
  console.log(md)
} finally {
  sh(`git worktree remove --force "${wt}"`, repoRoot)
  rmSync(wt, { recursive: true, force: true })
}
