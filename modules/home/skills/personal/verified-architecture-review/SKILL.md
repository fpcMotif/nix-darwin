---
name: verified-architecture-review
description: Run the improve-codebase-architecture review with a premise gate, so each deepening candidate is checked against the code before its card is published. Use for an architecture review, deepening candidates, a "check first" caveat, or an adversarial pass over candidates that a review already produced.
---

# verified-architecture-review

The upstream `improve-codebase-architecture` skill finds deepening candidates. This skill sits between its Explore step and its report. No card reaches the report until its **ledger entry** passes `scripts/ledger-check.ts`.

A candidate's **premise** is the fact that must hold for the deepening to pay off. A card's "Check first" line is a premise. A count in a card, such as "6 edits" or "5 copies", is a premise too.

## Steps

1. **Explore**: Follow Step 1 of `improve-codebase-architecture` (Skill tool, "improve-codebase-architecture"), or start from cards that a review already produced.
2. **Ledger**: Write one JSON entry per candidate to `<tmpdir>/architecture-ledger.json`, using the shape in [Ledger](#ledger). Fill it only from commands and reads you ran in this step.
3. **Premise**: Write the premise as a command or a file read, run it, and paste the output into `premise.output`. Set `premise.holds` to `true`, `false`, or `"partial"`. A premise that names a library default, a builder, or a flag needs a read of that source at the pinned version. Then check the premise against each concrete thing the candidate would classify or move, not only the general case. When a command reads boolean fields with jq, compare them explicitly. `false // null` is `null`, so the `//` operator reads a false flag as unset.
4. **Counts**: For every number in the card, record the command that measured it and its output. When no command can measure it, set `guess: true`. The card prints a guessed count with the word "guess". When the measured `value` differs from the card's `card` value, the card uses the measured value.
5. **Churn**: For a claim that tests or code break too often, run `git log --oneline -N -- FILE` and classify each commit as `rewording` (text changed, behavior did not) or `behavior` (behavior changed, so the test had to change). Only `rewording` commits count as brittleness. Skip `churn` when the card claims that each new item needs an edit, such as a name list. Those commits are `behavior` by nature, so record them as a count instead.
6. **Artifacts**: Render every generated file the candidate touches, such as a rendered guide, a settings file, or a host config. Read the rendered output, not only its source. Record each in `artifacts`, and put anything broken in `findings`. A finding outside the candidate is still a finding: report it apart from the cards.
7. **Stale check**: Run `git log --oneline -20 -- PATHS` on the candidate's files. If recent commits already did part of the move, record them in `premise.output`, set `holds` to `"partial"`, and shrink the card to the part that is left.
8. **Verdict**: Set `verdict` from [Verdict rules](#verdict-rules). Run `bun <this skill's folder>/scripts/ledger-check.ts <tmpdir>/architecture-ledger.json` and fix each error it prints. Done when it exits 0.
9. **Report**: Write the report with Step 2 of `improve-codebase-architecture`. Each card shows its verdict, its premise result, and its counts labeled measured or guess. Map `DO` to `Strong` and `SHRINK` to `Worth exploring`, and describe the smaller move. Leave `DROP` candidates out of the cards. List them under "Checked and dropped" with one line each.

## Ledger

```json
[
  {
    "id": "5",
    "title": "Render guide routing from mkHost",
    "premise": {
      "claim": "The four adapters repeat the same routing bullets",
      "command": "rg -n 'TypeScript, Python, Go, or Rust' modules/home",
      "output": "the lines it printed",
      "holds": "partial"
    },
    "counts": [
      { "claim": "copies of the language list", "card": 5, "value": 4, "command": "rg -c 'TypeScript, Python, Go, or Rust' modules/home", "output": "the counts it printed" },
      { "claim": "edits to add a guide", "card": 9, "value": 9, "guess": true }
    ],
    "artifacts": [
      { "path": ".omp/agent/AGENTS.md", "command": "nix eval of the rendered startup guide", "findings": [] }
    ],
    "verdict": "SHRINK",
    "reason": "Keep the bullets as one Markdown file with path placeholders, not prose built in Nix."
  }
]
```

`churn` appears only for a brittleness claim, as a list of `{ "sha", "kind" }`. `card` is the value the card states. `value` is what the command measured. The checker rejects placeholder text such as an ellipsis, so paste real output.

## Verdict rules

- **DO**: The premise holds, every count is measured, and the measured counts match the card.
- **SHRINK**: The premise holds only in part, a count shrank, or recent commits already did part of the move. Name the smaller move in `reason`.
- **DROP**: The premise fails for the main claim, or no measured count supports it.

The checker enforces these limits:

- A failed or partial premise can never be `DO`.
- A count that differs from the card can never be `DO`.
- A card whose counts are all guesses can never be `DO`.
- A brittleness claim whose churn is mostly `behavior` can never be `DO`.
