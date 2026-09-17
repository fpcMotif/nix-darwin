---
name: drafts-youtube-key-abstracts
description: "Classify and abstract YouTube links saved in Drafts.app: canonical video IDs, official title/channel/category, semantic genre, key idea. Use when the user wants YouTube catalogs, genre, main idea, or to process all YouTube drafts — not Takeout HTML dashboards."
---

# YouTube links in Drafts — key abstracts, not transcripts

User goal: every unique YouTube video in scope gets title, category, genre, and a short key idea. Transcripts are optional provenance for a small deep-read set. They are not the job.

## Scope (stabilize this first)

1. Extract URLs from every in-scope `ZCONTENT` row and from any named export files. Record source UUID and folder.
2. Canonicalize to video id:
   - `youtube.com/watch?v=`
   - `youtu.be/`
   - `youtube.com/shorts/`
   - `youtube.com/live/`
   - `youtube.com/embed/`
3. Deduplicate IDs. Repeated URLs (query strings, `si=`, `t=`) collapse to one row.
4. Join `yt-dlp` / oEmbed / `~/.cache/drafts-ledger/youtube.jsonl` **onto that set**. Never union cache-only URLs into the source set (this caused 6693 → 6527 → 3284 drift).

Print: source rows, unique IDs, cache hits, cache misses. Do not enrich until those four numbers are stable.

## Catalog columns (default)

One row per unique video id:

| id | title | channel | youtube_category | genre | key_idea | source_uuid | date | url |

- `title`, `channel`, `youtube_category`: from `uvx yt-dlp --dump-single-json --skip-download` or cache. Not from the Drafts first line.
- `genre`: semantic (lecture, music, demo, news, …) from title + description, not from the URL.
- `key_idea`: one or two sentences from title + description. Do not download captions unless the user asked for a deep read of a **small** set.
- Do not ship a five-row table unless the user said only those five.

## Deep read (only when asked, small N)

For a named handful of IDs:

```bash
uvx yt-dlp --dump-single-json --skip-download -- "https://www.youtube.com/watch?v=ID"
uvx yt-dlp --skip-download --write-auto-sub --sub-lang en --convert-subs vtt -- "https://www.youtube.com/watch?v=ID"
```

Derive main idea from captions. One contiguous cue plus timestamp is enough as an excerpt. Normalize repeated VTT cues. Keep the excerpt in a side dossier, not as extra catalog columns.

## What not to do

- Do not treat advisor's "five-row table" as the corpus when the user said there are many YouTube links.
- Do not rewrite transcripts or fix hyphenation in captions as the main task.
- Do not claim complete while unique IDs in the table disagree with the source set.
- Do not use Takeout `watch-history.html` pipelines unless the user asked for Takeout.

## Related skills

- `yt-takeout-pipeline` — Google Takeout HTML/CSV dashboards, different job.
- `drafts-ledger` — period digests of mixed captures.
- `drafts-automation-golden-rule` — 300 KB / 5k line ceiling; catalogs live on Desktop.
