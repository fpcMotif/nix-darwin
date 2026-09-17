---
name: spec-gap-analysis
description: "Analyze a specification document against an existing codebase, producing a CONTEXT.md (domain model, architecture, gap table, naming divergences, open decisions) and ADR files for unresolved decisions. Use when the user provides a spec/PRD and asks to map it against code, do a gap analysis, figure out what's missing, or prepare for implementation planning."
---

# Spec-vs-Codebase Gap Analysis

## When to use
- User provides a spec/PRD/functional-specification and an existing codebase
- User asks "what's missing", "map this spec", "figure out the gaps", "what needs building"
- Before starting implementation of a spec against existing code

## Procedure

### Phase 1: Deep Read (do not write anything yet)

1. **Read the spec fully.** Every section, every MUST/SHOULD/MAY. Note section numbers.
2. **Survey the codebase exhaustively.** Read directory structure, then every source file that could map to a spec requirement:
   - Package manifests (dependencies = stack decisions)
   - Router/routes (pages and API surface)
   - Store/state (data model)
   - Components/views (UI coverage)
   - DB schema (entity model)
   - Server entry + middleware (architecture)
   - Config files (deployment decisions)
   - Tests (what's verified)
   - Existing docs/ADRs (prior decisions)
3. **Do NOT install packages, create directories, or edit code.** This is analysis only.

### Phase 2: Map spec sections to code

For each spec section, determine:
- **Status:** Done / Partial / Missing
- **Current implementation:** Exact file paths and what they cover
- **Gap:** What's missing, with specifics
- **Priority:** P0 (safety/security/data-integrity blocker), P1 (required capability), P2 (optimization/SHOULD-level)

### Phase 3: Identify cross-cutting concerns

- **Naming divergences:** Where spec and code use different names for the same concept (e.g., `droneId` vs `device_id`, `lon` vs `lng`)
- **Architecture mismatches:** Where the code's structure conflicts with spec's prescribed structure
- **Unresolved decisions:** Choices the spec leaves open or where code took a different path than spec prescribes

### Phase 4: Produce documents

Dispatch parallel subagents for:

1. **`CONTEXT.md`** (project root) — sections:
   - Project Identity (name, purpose, actual stack)
   - Domain Model / Ubiquitous Language (every entity: term, meaning, code location, spec/code divergence)
   - Architecture Overview (current data flow, topology)
   - Spec Gap Analysis Table (section | requirement | status | current impl | gap | priority)
   - Naming Divergences (list with file references)
   - Open Decisions (list with ADR references)

2. **ADR files** (`docs/adr/NNN-topic.md`) — one per unresolved decision. Standard format:
   - Status: Proposed (never pick a winner unless user directs)
   - Context (what the spec says, what exists, what conflicts)
   - Decision Drivers
   - Options (2-3 with advantages and trade-offs)
   - Recommendation (or explicitly "no winner selected")
   - Consequences
   - Acceptance criteria

### Phase 5: Verify

- Read back every produced file
- Confirm no code changes, no package installs, no directory scaffolding leaked
- Check git status is clean except for new `.md` files

## Key rules

- **Analysis only.** Never edit source code, install packages, or create non-doc directories.
- **Name actual files.** Every claim in the gap table references real paths.
- **Be honest about coverage.** "Partial" means partial — say what's there AND what's missing.
- **ADRs stay Proposed.** Don't decide for the team unless explicitly asked.
- **Priorities are from the spec's perspective.** P0 = spec says MUST and it's safety/auth/data. P1 = spec says MUST and it's a feature. P2 = SHOULD or out-of-scope.
