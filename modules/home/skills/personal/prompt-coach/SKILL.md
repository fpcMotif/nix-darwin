---
name: prompt-coach
description: Coach the user to write sharper requests by closing the thinking and knowledge gaps behind a weak prompt. Use when a request shows a gap that will recur (a missing outcome, a mixed or symptom-level framing, a wrong assumption, or a missing concept), or when the user asks how to prompt better or how their asking has improved.
---

# Prompt coach

The user wants to get better at asking. Coach the **thinking and knowledge** behind a request. Read past spelling, grammar, and mixed languages: the user writes fast, and those slips never cost a turn.

Coach only a **recurring gap**: one that will cost a turn again in later, different requests. A one-off detail that only this task needed is a normal question, not a gap.

## The four gaps

Each gap has a tag, a coaching move, and a self-check question the user can ask before any future prompt. Pick the one gap that cost the most.

| Tag | Gap | Coaching move | Self-check question |
| --- | --- | --- | --- |
| `outcome` | The request names an action but not the result, or how to tell it is done. | Add the done-when to the rewrite. | "What will I see when this works?" |
| `framing` | The request mixes several problems, or aims at a symptom instead of its cause. | Split it, or name the cause behind the symptom. | "Is this the problem, or what the problem looks like?" |
| `assumption` | The request rests on a wrong belief about how the system works. | State the true model in one sentence. | "What must be true for my request to work?" |
| `concept` | The user lacks the term or idea that frames the problem. | Name the exact term from the symptom the user described, with a one-line definition and one close alternate. | "Is there a name for this?" |

For a `concept` gap in frontend work, check this harness's skill list for `emil-engineering-vocabulary`. When it is there, quote its definition.

## Steps

1. **Count**. Count earlier cards with the same tag in this folder:

   ```bash
   recall grep 'Sharper ask\*\* \(TAG\)' | rg -c 'Sharper ask'
   ```

   The count is a floor: `recall` caps its hits and reads one folder. Done when you hold a number.

2. **Write the card** as the report's last lines, above any What I need from you section. The count picks the form.

   **Count 0 or 1: the full card.**

   ```markdown
   **Sharper ask** (TAG): "the rewritten request, in the user's words plus the missing piece"
   **Learn**: **Name of the idea**: the term, model, or cause, in one sentence.
   **Next time**: the tag's self-check question.
   ```

   For a `concept` or `assumption` card, add the picture that the picture ladder below picks.

   **Count 2 or 3: the retrieval card.** The user answers the question in their head before reading the answer. Recall builds memory that rereading does not.

   ```markdown
   **Sharper ask** (TAG), gap N in this folder. Before you read on: what was missing from your request?
   ➡️ the missing piece, then the rewrite in quotes.
   **Habit**: one concrete step that supplies this piece before the user sends a prompt.
   ```

   N is the count plus one.

   **Count 4 or more: the drill offer.** Write the retrieval card, then offer one drill in one line: "Want a 3-prompt drill on TAG? I write three weak prompts, you fix them, I check." Offer it at most once per session.

   Done when the card's rewrite supplies the missing piece in the user's own words.

3. **Notice a win**. When the user's request clearly applies a habit from an earlier card, and that tag has a count of 2 or more, add one line in place of a card:

   ```markdown
   **Nice ask** (TAG): what the request did, and the turn it saved.
   ```

   Give at most one per session. Praise the specific move, never the user.

## Picture ladder

A `concept` or `assumption` gap is missing knowledge, and a picture teaches a model faster than a sentence. The two other tags are about the shape of the request, so they get no picture. An inline picture is enough for most ideas, so the picture stays in the reply. Count earlier lessons on the idea:

```bash
recall grep 'Learn\*\*: \*\*IDEA' | rg -c 'Learn'
```

| Rung | When | Delivery |
| --- | --- | --- |
| Sketch | The idea has parts that move: an order, a flow, or a state. | Automatic. One ASCII sketch of at most eight lines under the **Learn** line, in a `text` block. |
| Diagram | The idea is a system of four or more parts, such as an architecture, a data flow, or a lifecycle. | Automatic. One `mermaid` diagram under the **Learn** line. |
| Page offer | The idea comes back after an inline picture, so the picture did not stick. | One line at the end of the card that offers an `eli5` page. Make it only on the user's yes. |

The `show-me` skill holds the sketch and diagram views. An idea that is a single term with no moving parts stays on the **Learn** line alone.

## The drill

Run it only after the user accepts the offer.

1. Write three short, numbered weak prompts from the user's own projects, each with the same gap. Keep your own fixes for step 3.
2. Ask the user to rewrite all three in one reply.
3. Show your fix for each prompt in the grilling format (❓ the prompt, ➡️ your fix), and compare it with the user's rewrite. Name what each one fixed and what it still lacks.

Done when the user has rewritten all three and seen the comparison.

## Progress review

When the user asks how their asking has improved, run both commands in each project folder they name:

```bash
recall grep 'Sharper ask\*\* \((outcome|framing|assumption|concept)\)'
recall grep 'Nice ask\*\* \((outcome|framing|assumption|concept)\)'
```

Report a table with each tag's gaps and wins, name the tag with the most gaps, and give one habit for it.
