# Plan 008: `skill-router` reads multi-line YAML descriptions from SKILL.md frontmatter

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 534fc39..HEAD -- tools/skill-router/src/frontmatter.ts tools/skill-router/test`
> If `frontmatter.ts` changed, compare the "Current state" excerpt against the
> live code. On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `534fc39`, 2026-11-17

## At a glance

The frontmatter parser keeps only the text after the first colon on one line.
A description written as a YAML block (`description: >`) therefore parses as
the single character `>`. This plan teaches the parser folded and literal
blocks and indented continuation lines, and adds its first unit test.
One-line descriptions parse exactly as before.

## Why this matters

`skill-router` builds the catalog that tells an agent when to load each skill.
Fifteen skills under `modules/home/skills/personal/` use a block description.
Each shows up in the catalog as `>`, `>-`, or `|`. An agent choosing a skill
sees no "when to use" text for them, so those skills are never picked for the
right reason.

## Current state

Files:

- `tools/skill-router/src/frontmatter.ts` — the parser. 21 lines.
- `tools/skill-router/src/discover-local.ts:20` — the only caller: `const fm = parseFrontmatter(content);`
- `tools/skill-router/test/subprocess-gating.test.ts` — the only test file today.
- `tools/skill-router/bunfig.toml` — preloads `test/support/preload.ts` for every test.
- `tests/unit/skill-router-test.nix` — the Nix check `unit-skill-router`. It
  copies `tools/skill-router` and runs `bun test` offline.

`tools/skill-router/src/frontmatter.ts` today (whole file):

```ts
export type Frontmatter = {
  name?: string;
  description?: string;
};

export function parseFrontmatter(content: string): Frontmatter {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return {};

  const block = match[1];
  const result: Frontmatter = {};
  for (const line of block.split("\n")) {
    const idx = line.indexOf(":");
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    const value = line.slice(idx + 1).trim().replace(/^['"]|['"]$/g, "");
    if (key === "name") result.name = value;
    if (key === "description") result.description = value;
  }
  return result;
}
```

A real file that breaks it, `modules/home/skills/personal/simplify/SKILL.md:1-8`:

```markdown
---
name: simplify
description: >-
  Simplify a working diff with a four-angle sweep — reuse, simplification,
  efficiency, altitude — then apply the fixes. Quality only; correctness belongs
  to code review. Use for /simplify or a request to simplify changed code; the
  quick by-hand polish is `clean`.
---
```

The three block markers in use across the 15 files are `>`, `>-`, and `|`.

Test conventions, from `tools/skill-router/test/subprocess-gating.test.ts:1-5`:

```ts
import { afterEach, expect, test } from "bun:test";
...
import { buildCatalog, renderIntentBlock } from "../src/catalog.ts";
```

Tests import from `../src/<file>.ts` with the `.ts` extension and use
top-level `test(...)` calls, not `describe` blocks.

Repo rules that apply:

- Nix flakes read only git-tracked files. After creating a file, run `git add -N <path>`.
- A `doc-lock` hook blocks new or changed code comments outside docs work. Add no comments.
- Use `bun`, never `npm` or `npx`.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`. Use
  `z tools/skill-router && bun test` to run a command in a directory.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Tests, direct | `z tools/skill-router && bun test` | all tests pass, 0 fail |
| One file | `z tools/skill-router && bun test test/frontmatter.test.ts` | 7 pass, 0 fail |
| Nix gate | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-skill-router'` (from the repo root) | exit 0 |
| Live check | `nix run .#martin.skill-router -- catalog 2>/dev/null \| rg -n 'simplify'` — only if the attribute exists | the line shows prose, not `>-` |

If `nix run .#martin.skill-router` reports a missing attribute, skip the live
check. The unit tests are the gate.

## Scope

**In scope** (the only files you may modify):

- `tools/skill-router/src/frontmatter.ts`
- `tools/skill-router/test/frontmatter.test.ts` (create)

**Out of scope** (do NOT touch):

- Any `SKILL.md`. The files are valid YAML. The parser is wrong.
- `tools/skill-router/package.json`. Do not add a YAML dependency. The check
  runs offline with no `node_modules`.
- `tools/skill-router/src/sync.ts`. Plan 001 owns it.
- `tools/skill-router/src/catalog.ts` and `discover-local.ts`.

## Git workflow

- Branch: `advisor/008-skill-router-reads-multiline-descriptions`.
- One commit: `fix(skill-router): parse folded and literal frontmatter descriptions`.
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Write the failing tests

Create `tools/skill-router/test/frontmatter.test.ts`:

```ts
import { expect, test } from "bun:test";
import { parseFrontmatter } from "../src/frontmatter.ts";

const doc = (frontmatter: string): string => `---\n${frontmatter}\n---\n\n# Body\n`;

test("single-line values parse as before", () => {
  expect(parseFrontmatter(doc("name: clean\ndescription: Polish a diff."))).toEqual({
    name: "clean",
    description: "Polish a diff.",
  });
});

test("quotes around a single-line value are stripped", () => {
  expect(parseFrontmatter(doc('name: "jj"\ndescription: \'Use when: committing.\''))).toEqual({
    name: "jj",
    description: "Use when: committing.",
  });
});

test("a folded block joins its lines with spaces", () => {
  const parsed = parseFrontmatter(doc("name: simplify\ndescription: >-\n  Simplify a working diff,\n  then apply the fixes."));
  expect(parsed.description).toBe("Simplify a working diff, then apply the fixes.");
  expect(parsed.name).toBe("simplify");
});

test("a folded block keeps a blank line as a paragraph break", () => {
  const parsed = parseFrontmatter(doc("description: >\n  First paragraph\n  continues.\n\n  Second paragraph."));
  expect(parsed.description).toBe("First paragraph continues.\nSecond paragraph.");
});

test("a literal block keeps its line breaks", () => {
  const parsed = parseFrontmatter(doc("description: |\n  Line one.\n  Line two.\nname: chronicle"));
  expect(parsed.description).toBe("Line one.\nLine two.");
  expect(parsed.name).toBe("chronicle");
});

test("an indented continuation of a plain value is appended", () => {
  const parsed = parseFrontmatter(doc("description: Use when committing\n  or landing a change."));
  expect(parsed.description).toBe("Use when committing or landing a change.");
});

test("content without frontmatter yields an empty object", () => {
  expect(parseFrontmatter("# Just a heading\n")).toEqual({});
});
```

**Verify**: `z tools/skill-router && bun test test/frontmatter.test.ts` shows
exactly 3 pass and 4 fail. The folded, paragraph, literal, and continuation
tests fail.

### Step 2: Rewrite the parser

Replace the body of `tools/skill-router/src/frontmatter.ts` below the
`Frontmatter` type with:

```ts
const BLOCK_SCALAR = /^[>|][+-]?$/;
const INDENTED = /^\s/;

function foldLines(lines: string[]): string {
  return lines
    .join("\n")
    .trim()
    .split(/\n{2,}/)
    .map((paragraph) => paragraph.replace(/\n/g, " "))
    .join("\n");
}

export function parseFrontmatter(content: string): Frontmatter {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return {};

  const lines = match[1].split(/\r?\n/);
  const result: Frontmatter = {};
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (INDENTED.test(line)) continue;
    const idx = line.indexOf(":");
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    const head = line.slice(idx + 1).trim();

    const continuation: string[] = [];
    while (i + 1 < lines.length && (INDENTED.test(lines[i + 1]) || lines[i + 1].trim() === "")) {
      i += 1;
      continuation.push(lines[i].trim());
    }

    let value: string;
    if (BLOCK_SCALAR.test(head)) {
      value = head.startsWith("|") ? continuation.join("\n").trim() : foldLines(continuation);
    } else {
      value = [head.replace(/^['"]|['"]$/g, ""), ...continuation.filter((part) => part !== "")].join(" ").trim();
    }

    if (key === "name") result.name = value;
    if (key === "description") result.description = value;
  }
  return result;
}
```

Keep the `Frontmatter` type at the top of the file unchanged.

**Verify**: `z tools/skill-router && bun test test/frontmatter.test.ts` shows 7 pass, 0 fail.

### Step 3: Run the whole suite and the Nix gate

Run `git add -N tools/skill-router/test/frontmatter.test.ts` from the repo root.

**Verify**: `z tools/skill-router && bun test` shows 0 fail.
`nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-skill-router'` exits 0.

## Test plan

- New file `tools/skill-router/test/frontmatter.test.ts`, seven cases, listed in Step 1.
- The regression case is "a folded block joins its lines with spaces". It
  mirrors `modules/home/skills/personal/simplify/SKILL.md`.
- Structural pattern: `tools/skill-router/test/subprocess-gating.test.ts`.

## Done criteria

- [ ] `z tools/skill-router && bun test` reports 0 fail and includes 7 tests from `frontmatter.test.ts`
- [ ] `nix build --no-link '.#checks.aarch64-darwin.unit-skill-router'` exits 0
- [ ] `git status --short tools/skill-router` lists only `src/frontmatter.ts` and `test/frontmatter.test.ts`
- [ ] `tools/skill-router/package.json` is unchanged (`git diff --stat tools/skill-router/package.json` is empty)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `frontmatter.ts` does not match the excerpt in "Current state".
- An existing test in `subprocess-gating.test.ts` fails after Step 2.
- A SKILL.md in the repo uses a frontmatter shape the seven cases do not
  cover, such as a quoted string that spans lines. Report the file path.

## Maintenance notes

- This is a deliberate subset of YAML: top-level `key: value`, folded and
  literal blocks, and indented continuations. Nested maps and lists are ignored,
  as before. If skills start using richer frontmatter, replace the parser with a
  real YAML library that Bun provides, and keep these tests.
- A reviewer should run the live check and confirm that no catalog line shows a
  bare `>`, `>-`, or `|` as a description.
