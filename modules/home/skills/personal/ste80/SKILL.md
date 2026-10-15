---
name: ste80
description: Write or rewrite technical docs, READMEs, runbooks, and explanations 80% of the way to ASD-STE100 Simplified Technical English. Use when the user asks for STE, plain technical English, or a clearer rewrite.
---

# ste80

Write 80% of the way to ASD-STE100 Simplified Technical English. You know the specification. Keep its sentence rules and relax its dictionary: software nouns such as API, cache, and container stay.

## Steps

1. Pick the register. A file path or a document to rewrite is a **document**. A question or a topic is a **reply**.
2. Write the text to the rules below.
3. For a document, write the result to its file. Then run `bun <this skill's folder>/scripts/ste-check.ts FILE`. Fix each finding, or keep it when the rule's exception applies. Run the check again. Stop when each remaining finding is a kept exception.
4. For a reply, read your draft once against the rules before you send it.

## Rules

- **Length**: One instruction per sentence, 20 words at most. A description is 25 words at most. A paragraph has 6 sentences at most.
- **Condition first**: "If the token expires, refresh the session."
- **Verbs**: Active voice and simple tenses. Use the passive only in a description where the actor is unknown. Use -ing only inside a technical name.
- **Certainty**: Use must, can, or will. State uncertainty as a condition or a measured fact.
- **One meaning**: One word for one meaning in the whole text. After you pick "check", keep "check".
- **Whole sentences**: Keep articles and "that". A noun cluster has 3 words at most.
- **Facts**: State what a thing does and its measured effect, not how important it is.
- **Joins**: Join ideas with a period.
- **Reply register**: The first sentence answers. Write prose. Use a numbered list only for steps.
- **Escalate**: If a flow or state machine stays hard to follow in prose, add a Mermaid diagram.
