# Phase 2: Prototyper

**Status:** Q&A complete — implementation in progress

## Overview

Build the Prototyper agent — the entry point for new projects. It helps the user define what they want through visual exploration, reference analysis, and structured UX thinking. Outputs user stories, specs, and visual examples that the Architect can consume.

## Why Phase 2

The Prototyper is the natural starting point of the pipeline. It's interactive (always human-in-the-loop), making it a good second build — complex enough to stress-test the foundation but not as complex as the Builder. It also establishes the artifact format that the Architect will consume.

## Architecture

```
PROTOTYPER (Terminal 1) — Opus orchestrator
├── screenshot-analyzer   — ingests reference images, extracts patterns
├── ux-writer             — converts visual intent into user stories
├── wireframer            — generates HTML wireframes or layout descriptions
└── flow-mapper           — maps user journeys, state transitions, edge cases
```

### Execution Model

This agent is **always interactive** — the user drives the conversation. Typical session:

1. User shares reference screenshots, links, or describes what they want
2. screenshot-analyzer extracts layout patterns, components, color schemes
3. User and Prototyper discuss and refine the vision
4. wireframer produces layout descriptions or simple HTML mockups for key screens
5. flow-mapper works through user journeys and edge cases
6. ux-writer produces structured user stories with acceptance criteria
7. User reviews and approves the spec

The session may loop through steps 2-6 multiple times as the vision crystallizes.

### Output Format

```
artifacts/prototyper/
├── vision.md               # The what and why — project goals, target users, core value
├── references/             # Reference screenshots and analysis
│   ├── ref-001.png         # (user-provided)
│   ├── ref-001-analysis.md # What was extracted from this reference
│   └── ...
├── wireframes/             # Screen layouts
│   ├── screen-home.md      # Description + ASCII/HTML wireframe
│   ├── screen-dashboard.md
│   └── ...
├── user-stories/           # Individual story files
│   ├── us-001-user-login.md
│   ├── us-002-view-dashboard.md
│   └── ...
├── flows/                  # User journey maps
│   ├── flow-onboarding.md
│   ├── flow-core-workflow.md
│   └── ...
└── design-constraints.md   # Must-haves, brand rules, accessibility, platforms
```

#### User Story Format
```markdown
# US-001: User Login

## As a
New user

## I want to
Log in with my Google account

## So that
I can access my personalized dashboard

## Acceptance Criteria
- [ ] Google OAuth button visible on landing page
- [ ] Successful auth redirects to dashboard
- [ ] Failed auth shows clear error message
- [ ] Session persists across browser refresh

## Visual Reference
See: wireframes/screen-login.md
Similar to: references/ref-001-analysis.md (the login section)

## Notes
- No email/password auth — Google only for MVP
- Mobile-responsive required
```

## Agent Definitions

### Prototyper (Orchestrator)
- **Model:** Opus
- **Tools:** All
- **Role:** Guides the user through defining their vision. Coordinates sub-agents to analyze references, produce wireframes, map flows, and write stories. Maintains a conversational, collaborative tone.
- **Key behavior:** Asks clarifying questions. Shows rather than tells — produces concrete wireframes and examples rather than abstract descriptions. Pushes the user to think about edge cases.

### Sub-Agent: screenshot-analyzer
- **Model:** Opus (needs strong visual reasoning)
- **Tools:** Read (for images), Write, Glob
- **Role:** Ingests reference screenshots or mockups. Extracts: layout grid, component hierarchy, color palette, typography patterns, spacing system, interaction patterns.
- **Output:** Structured analysis per reference image.

### Sub-Agent: ux-writer
- **Model:** Sonnet
- **Tools:** Read, Write
- **Role:** Converts the vision, wireframes, and flow maps into structured user stories with acceptance criteria. Ensures stories are testable and implementation-ready.
- **Output:** Individual user story files.

### Sub-Agent: wireframer
- **Model:** Sonnet
- **Tools:** Read, Write, Bash (for generating simple HTML if needed)
- **Role:** Produces layout descriptions for each screen. Can generate simple static HTML wireframes for visual review in browser.
- **Output:** Screen description files, optionally with HTML preview files.

### Sub-Agent: flow-mapper
- **Model:** Sonnet
- **Tools:** Read, Write
- **Role:** Maps user journeys through the application. Identifies: entry points, happy paths, error states, edge cases, state transitions.
- **Output:** Flow files with step-by-step journeys.

## Human-in-the-Loop

This agent has the **most** human interaction of all five:

| Step | Human Action | Agent Action |
|------|-------------|--------------|
| Start | Share references + describe vision | Analyze and reflect back understanding |
| Refine | Correct, redirect, add detail | Update analysis, produce wireframes |
| Review wireframes | Approve, request changes | Revise wireframes |
| Review flows | Approve, add edge cases | Update flows |
| Review stories | Approve, adjust scope | Finalize stories |
| Handoff | Confirm spec is ready | Generate handoff to Architect |

The Prototyper never proceeds to generating the handoff document without explicit user approval.

---

## Q&A Decisions (2026-03-22)

### Input Formats
- Screenshots, URLs, written descriptions/ideas. Figma links in the future.
- Extract exact colors, fonts, and design system elements (layout, buttons, color use, components)
- Always ask upfront: "Is this the target UI or just inspiration?"
- Design system input per project: file, URL, or screenshot

### Skills (5 entry points)
- **Explore** — vague idea → help figure out what to build. Includes user research.
- **Design App** — full app → complete flow wireframes, all screens. Includes user research.
- **Design Feature** — feature for existing app → 5+ alternative approaches. First checks existing docs (PRD, design system). Asks if not found.
- **Refine Detail** — specific interaction/element → single draft, iterate. First checks existing docs. Asks if not found.
- **Spec from Reference** — "here's exactly what I want" → extract precise spec. Includes user research.

### Scope & Output
- Ask expected outcome/scope before starting any work
- UX-focused. Lorem ipsum for content. No data modeling (unless non-visual like APIs)
- No stack suggestions — document UX tradeoffs that affect architecture (e.g., "needs real-time", "must work offline")
- Rough draft design system — Architect's designer finalizes
- Output depth scales with scope:
  - Full app: clickable wireframe HTML first, then visual exploration screens
  - Feature: 5+ different visual options representing clear tradeoffs, scrollable in browser
  - Detail: single draft, iterate from there
- Iteration narrows the funnel: rough → options → refined → detailed

### Web Search Tool Selection
| Need | Tool |
|------|------|
| Search for references | Built-in WebSearch |
| Read a page for inspiration | Built-in WebFetch |
| JS-rendered pages (SPAs) | Jina Reader: `WebFetch("https://r.jina.ai/URL")` |
| Screenshot a live site | Playwright via Bash script |

### User Stories
- Include tradeoff decisions with rationale (what was chosen, what was sacrificed)
- Happy path narrative (step-by-step walkthrough)
- Documented unhappy paths (error states, edge cases)
- User's explicit decisions during session marked as constraints (not suggestions)
- Usage context: frequency, environment, actor type (human, system, API, scheduled job)

### Handoff to Architect
- Manual — user reviews handoff, then starts Architect
- Handoff artifacts include: problem definition, PRD, success criteria, draft design system, user stories, flows, wireframes
