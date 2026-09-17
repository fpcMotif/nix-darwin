---
name: zvec-grep-guide
description: "Index, query, and integrate zvec-grep (zg) for hybrid semantic and keyword workspace search"
---

# zvec-grep (zg) Guide

## Overview
`zg` (`@zvec/zvec-grep`) is a local-first workspace search layer combining ripgrep, BM25 keyword search, and vector embeddings for human developers and AI agents.

Binary installed at: `~/.local/bin/zg` (requires Node 22+ runtime via host `node`).

## Core Workflows

1. **Exact / Regex Search (Managed ripgrep - no index needed)**:
   ```bash
   zg query --rg -F "AuthService" src
   zg query --rg -n "TODO|FIXME" .
   ```

2. **Full-Text Keyword Search (BM25)**:
   ```bash
   zg query --fts "authentication handler"
   ```

3. **Hybrid Semantic & Natural Language Query**:
   ```bash
   zg query "where theme preferences are restored" --limit 5
   zg query --human "plugin lifecycle"
   ```

4. **Building / Updating Workspace Index**:
   ```bash
   # Index with lightweight local embedding model:
   zg index --embedding local/potion-code-16m-v2
   # Incremental update:
   zg index
   # Check index status:
   zg status
   ```

5. **Agent Integrations & MCP**:
   ```bash
   zg install --target opencode --yes
   zg install --target codex --yes
   zg server on
   zg server status
   ```

## Search Tool Selection Matrix

| Need | Tool | Latency / Characteristic |
|---|---|---|
| Exact symbol definition / word lookup | `codedb` (`codedb word`, 0.9ms) | O(1) inverted index, 2MB cap |
| Fuzzy file discovery / frecency | `fff` (`find_files`) | Git-dirty boost, interactive |
| Fast monorepo regex & multiline | `rg` | Stream regex, `-U` for multiline |
| Structural AST pattern match | `ast-grep` (`sg`) | AST syntax-aware query & rewrite |
| Semantic intent / hybrid retrieval | `zg` (`zvec-grep`) | Vector + BM25 + ripgrep RRF ranking |
