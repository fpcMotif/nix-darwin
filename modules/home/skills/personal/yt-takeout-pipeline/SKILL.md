---
name: yt-takeout-pipeline
description: Parse Google Takeout YouTube watch history and playlist CSVs into a unified dataset with safe HTML dashboard generation and metadata resolution via yt-dlp
---

# YouTube Takeout + yt-dlp Pipeline

Procedure for parsing Google Takeout YouTube watch history (`watch-history.html`) and playlist CSVs alongside live `yt-dlp` metadata exports (`WL`, `LL`) into a unified JSONL dataset and interactive single-file HTML dashboard.

## Key Steps

1. **Ingest Watch History**:
   Parse `Takeout/YouTube and YouTube Music/history/watch-history.html` for watched video records (title, channel, video ID, timestamp).

2. **Ingest Playlist CSVs**:
   Parse `Takeout/YouTube and YouTube Music/playlists/*.csv` for playlist memberships (`Video ID`, `Time Added`). Parse `playlists.csv` manifest for playlist names.

3. **Live Metadata & Provenance Extraction**:
   Extract live playlists (Watch Later `WL`, Liked Videos `LL`) via `uvx yt-dlp`:
   ```bash
   uvx yt-dlp --no-config --cookies-from-browser chrome --flat-playlist --skip-download --ignore-errors -j "https://www.youtube.com/playlist?list=WL"
   ```
   Append metadata to `$O(1)$` JSONL cache (`data/metadata_cache.jsonl`) and provenance to (`data/playlist_memberships.jsonl`).

4. **Multi-Source Facet Modeling**:
   Track independent boolean flags:
   - `isWatched`: present in watch history
   - `inTakeoutWatchLater` vs `inLiveWatchLater`
   - `inTakeoutLiked` vs `inLiveLiked`

5. **Safe HTML Dashboard Generation**:
   - Neutralize script tag breakout in serialized JSON: `JSON.stringify(data).replace(/</g, "\\u003c").replace(/>/g, "\\u003e")`.
   - Render table cells using DOM element creation (`document.createElement` and `textContent`) to prevent stored XSS from malicious video titles.
