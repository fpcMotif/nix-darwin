---
name: aily-batch-autoresearch-workflow
description: "Repeatable procedure for running the feishudoc aily batch conversion autoresearch loop: benchmark scoring, defect fixing, and metric tracking on branch autoresearch/aily-batch-260820"
---

# Aily Batch Conversion Autoresearch Workflow

## Context
- Repo: `feishudoc` — converts 270 enterprise SOP PDFs into Feishu Aily-friendly Markdown.
- Branch: `autoresearch/aily-batch-260820`
- Benchmark: `bash autoresearch.sh` → runs `gemini-autore/score_gemini_autore.py` + readability/figure defect scorers.
- Primary metric: `clean_pass` (target 252/252). Secondary: `read_defects`, `runon_para`, `fig_issues`, `total_score`.

## Key Files
- `gemini-autore/build_gemini_autore.py` — rebuilds `current.md` from `cursor-revision/` sources
- `gemini-autore/score_gemini_autore.py` — scores all 252 docs, outputs METRIC lines
- `autoresearch.sh` — orchestrates build + score + readability defects + figure QA
- `管理文件汇总_md/` — mirror tree (deliverable)
- `管理文件汇总_md/_store/` — version lineage (raw/claude/gemini/docs/log.jsonl/manifest.json)
- `管理文件汇总_figures/_verdicts_round*/` — vision figure verdicts
- `review_pack/pages/` — rendered page PNGs for multimodal inspection

## Workflow Per Iteration
1. Read `autoresearch/read_defects.json` and `fig_issues.json` for targeted fixes
2. Apply fixes to files in `管理文件汇总_md/` (mirror tree) AND `cursor-revision/` (source)
3. Rebuild: `uv run python gemini-autore/build_gemini_autore.py`
4. Run benchmark: `bash autoresearch.sh`
5. Run experiment: use `run_experiment` tool
6. Log result: use `log_experiment` with status=keep, all metrics
7. Commit: `git add -A && git commit -m "..."`

## Defect Fix Patterns
- **Run-on paragraphs**: Split at sentence/clause boundaries into numbered items (`1. `, `2. `, etc.)
  - Thai text: split at word boundaries (~80 char chunks, Thai has no sentence-ending punctuation)
  - Legal T&C: split at clause connectors (`provided that`, `including`, `§`, `Neither Party`)
  - Numbered legal items: split long content into lettered sub-clauses (`a.`, `b.`, `c.`)
- **Double spaces**: Fix `\S  +\S` outside tables/fences; also remove inline code markers that cause scorer artifacts
- **CJK-Latin tight**: Add space between CJK chars and Latin/digits in Chinese SOPs
- **Figure anchoring**: Copy assets from `管理文件汇总_figures/<path>/assets/` to doc dir; add `> 📋 **操作指引**\n![alt](assets/fid.png)` cards
- **Flowcharts**: Always pair Mermaid diagram with native Markdown step table for Feishu AI indexing
- **Data tables as images**: Transcribe into native Markdown tables with real header rows

## Metric Targets
| Metric | Target | Current Best |
|--------|--------|-------------|
| clean_pass | 252 | 252 ✅ |
| read_defects | <50 | 44 |
| runon_para | <10 | 11 |
| double_space | 0 | 0 ✅ |
| punct_glue | 0 | 0 ✅ |
| cjk_latin_tight | 0 | 0 ✅ |
| fig_issues | 0 | 0 ✅ |
| total_score | >25000 | 25023.9 |

## Gotchas
- `score_gemini_autore.py` strips inline code before checking double_space — removing backtick markers fixes false positives
- Thai text has no standard sentence-ending punctuation — use word-boundary splitting instead
- Shared T&C boilerplate repeats across company trees — fix one pattern, apply to all copies
- `build_gemini_autore.py` reads from `cursor-revision/<doc_id>/current.md` OR `cursor-revision/<doc_id>.md` (flat file takes priority if dir doesn't exist)
- Always sync changes between `gemini-autore/`, `cursor-revision/`, and `管理文件汇总_md/` mirror tree
