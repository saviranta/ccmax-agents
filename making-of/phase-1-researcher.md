# Phase 1: Researcher

**Status:** Q&A complete — implementation in progress

## Overview

Build the Researcher agent — the most independent of the five top-level agents. It doesn't depend on the others and can be tested standalone. It employs specialized sub-agents to answer research questions ranging from library evaluation to competitive analysis to quantitative research.

## Why Phase 1

The Researcher has no dependencies on other agents, making it ideal for validating the foundation (Phase 0) works correctly — project state, audit logging, artifact output, sub-agent coordination patterns. Patterns proven here become templates for the other four agents.

## Architecture

```
RESEARCHER (Terminal 5) — Opus orchestrator
├── web-searcher      — targeted web searches, structured extraction
├── doc-reader        — reads documentation, extracts relevant sections
├── repo-analyzer     — clones/reads GitHub repos, analyzes patterns
├── comparator        — structured comparison tables
├── statistician      — data analysis, benchmarking, quantitative research
└── summarizer        — condenses findings into actionable recommendations
```

### Execution Model

1. User provides a research question or topic
2. Researcher (orchestrator) decomposes the question into sub-tasks
3. Sub-agents execute in parallel where possible (e.g., web-searcher + doc-reader)
4. Orchestrator synthesizes results, may trigger follow-up sub-tasks (max 3 cycles)
5. Final output written to `artifacts/researcher/[topic-slug]/`

### Output Format

Each research task produces:
```
artifacts/researcher/[topic-slug]/
├── summary.md          # Executive summary with recommendations
├── findings/           # Detailed findings from each sub-agent
│   ├── web-search.md
│   ├── docs.md
│   └── repo-analysis.md
├── comparisons/        # Structured comparison tables (if applicable)
└── raw/                # Raw data, links, references
```

## Agent Definitions

### Researcher (Orchestrator)
- **Model:** Opus
- **Tools:** All (needs to coordinate sub-agents)
- **Role:** Decomposes research questions, dispatches to sub-agents, synthesizes results, identifies gaps, triggers follow-up queries
- **Key behavior:** Never answers from training data alone — always verifies via sub-agents. Presents findings with confidence levels and source attribution.

### Sub-Agent: web-searcher
- **Model:** Sonnet
- **Tools:** WebSearch, WebFetch, Read, Write
- **Role:** Performs targeted web searches, fetches and extracts structured data from web pages
- **Output:** Structured findings with URLs, dates, key quotes

### Sub-Agent: doc-reader
- **Model:** Sonnet
- **Tools:** WebFetch, Read, Write
- **Role:** Reads official documentation pages, extracts relevant sections, summarizes API surfaces
- **Output:** Documentation summaries with version numbers and links

### Sub-Agent: repo-analyzer
- **Model:** Sonnet
- **Tools:** Bash, Read, Glob, Grep, Write
- **Role:** Clones or reads GitHub repositories, analyzes architecture, patterns, dependencies, activity
- **Output:** Repo analysis with structure, key patterns, strengths/weaknesses

### Sub-Agent: comparator
- **Model:** Sonnet
- **Tools:** Read, Write
- **Role:** Takes findings from other sub-agents, produces structured comparison tables
- **Output:** Markdown tables with criteria, scores, pros/cons

### Sub-Agent: statistician
- **Model:** Sonnet
- **Tools:** Bash, Read, Write
- **Role:** Quantitative analysis — download counts, benchmark data, adoption trends, performance comparisons
- **Output:** Data tables, charts (if applicable), statistical summaries

### Sub-Agent: summarizer
- **Model:** Sonnet
- **Tools:** Read, Write
- **Role:** Final synthesis — takes all findings and produces an executive summary with clear recommendations
- **Output:** Single summary.md with recommendations ranked by confidence

## Interaction Patterns

### Mode 1: Interactive Research
User asks a question, Researcher works through it with status updates, user can redirect mid-research.

### Mode 2: Background Research
User provides a research brief, Researcher works autonomously and writes output to artifacts. User reviews when ready.

### Mode 3: Project-Linked Research
Architect or Builder triggers a research question (via handoff). Researcher answers and writes a handoff back.

## Audit Trail

Every sub-agent invocation logged:
```jsonl
{"ts":"...","agent":"researcher","sub_agent":"web-searcher","action":"search","query":"next.js vs remix 2026","turns_used":8,"status":"complete"}
{"ts":"...","agent":"researcher","sub_agent":"comparator","action":"compare","topic":"next.js vs remix","turns_used":4,"status":"complete"}
```

---

## Q&A Decisions (2026-03-22)

### Scope
- Deep web search, library/GitHub repo analysis, local document analysis, quantitative/qualitative research
- No topic restrictions
- Repo analysis via temp clones, cleaned up after

### Modes
- **Interactive** — own terminal, user drives the conversation
- **Autonomous sub-agent** — called by Architect or Builder, runs without human-in-the-loop

### Sub-Agents (7)
- **deep-searcher** — extensive multi-source web search. Uses WebSearch + WebFetch + Jina Reader + Brave Search MCP.
- **repo-analyzer** — temp clones, analyzes architecture/patterns/quality/activity, cleans up after.
- **doc-reader** — reads PDFs, local files, documentation sites. Extracts structured information.
- **data-analyst** — quantitative work: Python (pandas/matplotlib), produces CSV, SQL, chart images. Sets up dependencies as needed.
- **chrome-browser** — authenticated pages, visual inspection, JS-rendered sites. Dedicated sub-agent with `excludedCommands` sandbox bypass (Option A for Playwright security).
- **comparator** — takes findings from other sub-agents, produces structured comparison tables with recommendations.
- **report-writer** — produces research reports in md, docx, pptx. Has skills for different report types (business report, tech-stack decision, etc.).

### Web Tools
| Need | Tool |
|------|------|
| Search for sources | Built-in WebSearch + Brave Search MCP |
| Read a page | Built-in WebFetch |
| JS-rendered pages | Jina Reader: `WebFetch("https://r.jina.ai/URL")` |
| Authenticated / visual | Chrome MCP (claude with chrome) |
| Screenshots of sites | Playwright via chrome-browser sub-agent (sandbox bypass) |

### Network Security
- Allowlist: `api.search.brave.com`, `github.com`, `*.github.com`, `pypi.org` + project domains
- WebFetch/WebSearch/Chrome MCP bypass sandbox network restrictions (built-in tools)
- Playwright isolated in dedicated sub-agent with `excludedCommands` bypass

### Research Storage
```
research/
├── topics/           # General research, organized by topic
│   ├── auth-libraries/
│   └── index.md
├── projects/         # Project-specific research
│   ├── my-app/
│   └── index.md
└── temp/             # Auto-pruned after 30 days
    └── index.md
```
- Researcher asks after each task: permanent (topics/ or projects/) or temp (30-day auto-prune)
- Versioned with dates, indexed for discovery

### Output Formats
- Qualitative: markdown
- Quantitative: CSV, SQL, chart images (formats usable in other programs)
- Reports: md, docx, pptx via report-writer sub-agent

### Executive Summary
Always produced for every research task:
- **Problem** — short paragraph
- **What was found** — short bullets
- **What is recommended** — short bullets
- **What is unknown** — short bullets
