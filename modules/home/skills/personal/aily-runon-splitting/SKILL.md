---
name: aily-runon-splitting
description: Split long run-on legal/prose paragraphs into numbered clause blocks to reduce runon_para count in aily readability scoring.
---

# Aily Run-On Paragraph Splitting

## Goal
Reduce `runon_para` count in the readability defect scorer by splitting long legal/prose paragraphs into numbered clause blocks that aily can chunk cleanly.

## Detection
A run-on paragraph is plain prose over 250-400 chars with fewer than 3 sentence-ending punctuation marks (period, semicolon, exclamation, question mark in either Latin or CJK), not starting with table pipe, heading, blockquote, image, or a numbered list marker.

Common in legal Terms and Conditions documents where the source PDF has one massive paragraph per article.

## Fix Procedure

Split the paragraph on sentence boundaries followed by capital or CJK start. Group sentences into chunks under 200 chars each. Number each chunk as `1. `, `2. `, etc for native list syntax. Preserve original text verbatim within each chunk. Skip fenced code blocks, Mermaid diagrams, tables, lists, and headings.

## Key Rules
- Only split single-line paragraphs
- Group sentences into chunks of 200 chars or less
- Use native Markdown numbered list syntax
- Never rewrite content inside chunks

## Verification
Run `bash autoresearch.sh` and check that `METRIC runon_para` decreased without any new violations appearing.
