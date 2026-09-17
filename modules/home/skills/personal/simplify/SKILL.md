---
name: simplify
description: >-
  Simplify a working diff with a four-angle sweep — reuse, simplification,
  efficiency, altitude — then apply the fixes. Quality only; correctness belongs
  to code review. Use for /simplify or a request to simplify changed code; the
  quick by-hand polish is `clean`.
---

# Simplify

Raise the quality of the changed code and keep its behavior. A correctness bug
you notice goes in the report for a separate review.

## Steps

1. **Scope.** Collect the diff under review.
   - Git: `git diff @{upstream}...HEAD`, falling back to `git diff main...HEAD`
     or `git diff HEAD~1`. Add `git diff HEAD` when the tree has uncommitted
     changes or the range is empty.
   - Jujutsu (a `.jj` directory): `jj diff --from 'trunk()' --to @`.
   - A PR number, branch, or path in the request replaces these defaults.
   - Leave out files that belong to other work in progress, and name them in
     the report.

   Done when the scope commands yield exactly the hunks under review.

2. **Review.** Give each reviewer the scope commands and one angle from
   [Angles](#angles). Where the host runs subagents, dispatch all four in one
   parallel batch; otherwise work the angles yourself as four separate passes,
   finishing each before the next. Reviewers read and report; step 3 owns every
   edit. Each finding carries `file:line`, a one-line summary, the proposed fix,
   and its concrete cost.

   Done when all four angles have reported, each with findings or an explicit
   "nothing found".

3. **Apply.** Merge findings that name the same line or mechanism. Read the code
   behind each finding, then fix it or record a skip with its reason. Skip when
   the fix would:
   - change intended behavior — stored data, persisted enum values, public
     APIs, and already-scheduled jobs all count;
   - reach well outside the reviewed diff;
   - rest on a premise the code disproves.

   Keep UI code to its agreed visual design.

   Done when every finding is fixed or skipped with a reason.

4. **Verify.** Read the resulting diff. Run the project's required checks and the
   tests covering touched code. Repair or revert any fix that breaks one.

   Done when the checks pass.

5. **Report.** State what was fixed, what was skipped and why, which checks ran,
   and any files left out of scope. Commit, push, or merge only within the user's
   authorization.

## Angles

**Reuse.** New code that re-implements something the codebase already has.
Search shared utilities and the files beside the change; name the helper to call,
with its `file:line`.

**Simplification.** Complexity the diff adds: redundant or derivable state,
near-copies with slight variation, deep nesting, dead or unreachable code,
temporary logging, an abstraction with a single caller. Name the simpler form
that does the same job.

**Efficiency.** Waste the diff adds: repeated computation or I/O, independent
operations run in sequence, blocking work on startup or hot paths, long-lived
closures that keep a large scope alive (a struct holding only the needed fields
is cheaper). Name the cheaper form and why the cost is real at this project's
scale.

**Altitude.** Whether each change fixes the root cause at the right depth. A
special case layered on shared infrastructure means the fix sits too shallow;
name the general change to the mechanism. One rule threaded through several
layers means it sits in too many places; name the one layer that should own it.
