---
name: feishu-sop-mermaid-table-extraction
description: Convert legacy Feishu SOP image screenshots (flowcharts and data tables) into native Markdown tables and verified Mermaid diagrams for Feishu aily RAG knowledge bases.
---

# Feishu SOP Mermaid & Table Extraction Procedure

## Overview
When transforming legacy Feishu Wiki/Doc SOPs into AI-friendly Markdown for Feishu aily RAG knowledge bases:
1. **Never rely purely on OCR for flowcharts**: Flowcharts with conditional branching, parallel lanes, and multi-user roles (e.g. Operator vs Auditor) require visual inspection using image readers/tools to construct accurate Mermaid (`graph TD` or `sequenceDiagram`).
2. **Convert table screenshots to native Markdown**: Screenshots of Excel sheets, account lists, and permission matrices must be transcribed into clean, row-based Markdown tables to enable 100% semantic retrieval in aily.
3. **Zero Hallucination Policy**: Every single number, SAP T-code, and entity name must strictly match the primary source.
