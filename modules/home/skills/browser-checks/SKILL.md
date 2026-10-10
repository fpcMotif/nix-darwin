---
name: browser-checks
description: Use before driving a browser for a UI check — screenshotting pages, clicking through a flow, or running browser tests. Routes repeated checks to a project script, exploration to agent-browser batch, and test suites to Playwright.
---

# Browser checks

Each agent step costs seconds of model time; the browser itself costs milliseconds.
Pick the route that takes the fewest steps.

| Job | Route |
|---|---|
| The same check after every change: a screenshot sweep, before and after | Project script |
| Exploring a page: click through a flow, find what is wrong | agent-browser batch |
| The project's browser tests | Playwright |

## Project script

1. Look in `package.json` scripts for one that already shoots the pages, such as `shots`. Run it.
2. Without one, write it: one browser, every page in parallel, one screenshot file per page.
   Use the project's Playwright when `package.json` has it; otherwise loop over agent-browser batch.
   Add it to `package.json` scripts so the next session finds it.
3. Done when one command writes every screenshot.

## agent-browser

agent-browser is a per-project dev dependency, carried by projects that take UI screenshots.

- Missing from `package.json`: run `bun add -d agent-browser`.
  Leave its postinstall blocked; the package ships the native binary.
  Chrome comes from `bunx agent-browser install`, once per machine.
- Run it as `bunx agent-browser`, which resolves the project's copy.
  Flags are in `bunx agent-browser --help`.
  For login, tabs, and parallel sessions, read `bunx agent-browser skills get core` (about 38 KB).
- Make each check one call:

  ```bash
  bunx agent-browser --session NAME batch --bail "open URL" "wait SELECTOR" "snapshot -i" "screenshot PATH" "close"
  ```

- Use a new NAME for every run, such as `hero-1`, then `hero-2`.
  On 0.39.0, reopening a name right after `close` fails, and the session stays on `about:blank`.
  The next `screenshot` still reports success, so the image is blank.
  Drop this rule once vercel-labs/agent-browser#1837 is fixed.
- Give each parallel subagent its own NAME.
- Wait for the selector or text the check needs. `networkidle` suits only pages that go quiet.
- When a command hangs, run `bunx agent-browser doctor`.

## Playwright tests

Run the project's own test command, such as its `test:e2e` script.
Playwright stays the test runner; this skill covers checks outside the suite.
