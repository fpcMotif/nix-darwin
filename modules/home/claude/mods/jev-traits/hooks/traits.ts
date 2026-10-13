// Same layout as traits-poc: every folder under .agents/traits is a group
// (Local folders and Git submodules alike) and every top-level *.md file in it is a trait.
export const TRAITS_DIR = '.agents/traits'

export type Trait = {
  readonly id: string
  readonly path: string
  readonly title: string
  readonly body: string
  readonly paths: readonly string[]
  readonly when: readonly RegExp[]
}

export const dirOf = (path: string) => path.slice(0, Math.max(path.lastIndexOf('/'), 0)) || '/'

export const relativeTo = (root: string, path: string) =>
  path.startsWith(`${root}/`) ? path.slice(root.length + 1) : path

export function parseTrait(id: string, path: string, text: string): Trait {
  const front = /^---\r?\n([\s\S]*?)\r?\n---[ \t]*(?:\r?\n|$)/.exec(text)
  const meta = front ? parseFrontmatter(front[1] ?? '') : {}
  const body = (front ? text.slice(front[0].length) : text).trim()
  const firstLine = body.split('\n').find(line => line.trim()) ?? id
  return {
    id,
    path,
    title: firstLine.replace(/^#+\s*/, '').trim().slice(0, 140),
    body,
    paths: meta.paths ?? [],
    when: (meta.when ?? []).flatMap(source => {
      try {
        return [new RegExp(source, 'im')]
      } catch {
        return []
      }
    }),
  }
}

function parseFrontmatter(block: string): Record<string, string[]> {
  const meta: Record<string, string[]> = {}
  let list: string[] | undefined
  for (const line of block.split(/\r?\n/)) {
    const item = /^\s+-\s+(.*)$/.exec(line)
    if (item && list) {
      list.push(unquote(item[1] ?? ''))
      continue
    }
    const pair = /^([A-Za-z_]+):\s*(.*)$/.exec(line)
    if (!pair) continue
    list = flowList(pair[2] ?? '')
    meta[pair[1] ?? ''] = list
  }
  return meta
}

function flowList(value: string): string[] {
  const text = value.trim()
  if (!text) return []
  if (text.startsWith('[') && text.endsWith(']'))
    return text.slice(1, -1).split(',').map(unquote).filter(Boolean)
  return [unquote(text)]
}

function unquote(value: string): string {
  const text = value.trim()
  if (text.length >= 2 && text.startsWith("'") && text.endsWith("'")) return text.slice(1, -1).replaceAll("''", "'")
  if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
    try {
      return JSON.parse(text) as string
    } catch {
      return text.slice(1, -1)
    }
  }
  return text
}

// `paths` scopes a trait the way perch's `where` does; `when` is jev-lint's cheap
// regex gate, so a trait about one API is only asked when the code mentions it.
export function appliesTo(trait: Trait, relPath: string, code: string): boolean {
  const include = trait.paths.filter(glob => !glob.startsWith('!'))
  const exclude = trait.paths.filter(glob => glob.startsWith('!')).map(glob => glob.slice(1))
  if (include.length > 0 && !include.some(glob => globMatch(glob, relPath))) return false
  if (exclude.some(glob => globMatch(glob, relPath))) return false
  return trait.when.length === 0 || trait.when.some(pattern => pattern.test(code))
}

const compiled = new Map<string, RegExp>()

export function globMatch(glob: string, relPath: string): boolean {
  const normalized = glob.replace(/^\.\//, '').replace(/\/$/, '/**')
  const target = normalized.includes('/') ? relPath : relPath.slice(relPath.lastIndexOf('/') + 1)
  let pattern = compiled.get(normalized)
  if (!pattern) {
    pattern = globToRegExp(normalized)
    compiled.set(normalized, pattern)
  }
  return pattern.test(target)
}

const escapeRegExp = (text: string) => text.replace(/[.+^${}()|[\]\\*?]/g, '\\$&')

function globToRegExp(glob: string): RegExp {
  let source = ''
  for (let i = 0; i < glob.length; i++) {
    const char = glob[i] ?? ''
    if (char === '*' && glob[i + 1] === '*') {
      const isSegment = glob[i + 2] === '/'
      source += isSegment ? '(?:.*/)?' : '.*'
      i += isSegment ? 2 : 1
    } else if (char === '*') source += '[^/]*'
    else if (char === '?') source += '[^/]'
    else if (char === '{' && glob.indexOf('}', i) > i) {
      const end = glob.indexOf('}', i)
      source += `(?:${glob.slice(i + 1, end).split(',').map(escapeRegExp).join('|')})`
      i = end
    } else source += escapeRegExp(char)
  }
  return new RegExp(`^${source}$`)
}
