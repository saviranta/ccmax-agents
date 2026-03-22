# Phase 6: Integration & Polish

**Status:** Q&A complete — ready for implementation

## Overview

Final phase — connect all five agents into a working pipeline, build the dashboard, add cross-agent metrics, and validate the system with a papertrail simulation.

## Why Phase 6

Integration issues only surface when agents work together. This phase is about finding and fixing the seams between agents, plus adding observability.

---

## Deliverables

### 1. End-to-End Pipeline Test

Run a papertrail simulation to exercise all handoff points across the full pipeline:
```
Prototyper → Architect → Builder → Launcher
```

Goal: surface structural issues, missing artifacts, and broken handoffs without building a real project. A real project will be run separately after the system is validated.

No case study documentation required.

### 2. Dashboard

Two versions:

**Terminal dashboard** (per-project, SSH/remote-friendly)
- Launched per project: `dashboard.sh <project-path>`
- Refreshes periodically, read-only

**Web dashboard** (multi-project, local)
- One tab/page per active project
- Richer layout, more information density

Both versions share four views:

| View | Contents |
|------|----------|
| **Running Now** | Current phase, active agents, what's happening right now |
| **Task Graph** | Detailed breakdown by phase, checkpoints, milestones, task statuses |
| **Metrics** | Turn usage, token usage, done/failed/parked counts, review pass rates |
| **Audit Log** | Full timestamped event history |

### 3. Cross-Agent Metrics

Aggregate metrics from audit logs, written to `artifacts/metrics/` after each build cycle:
- Tasks completed vs. parked vs. failed per builder type
- Review pass rate (first attempt vs. after fix cycles)
- Average turns per task by size (S/M/L)
- Stall frequency and causes
- Phase completion times
- Token usage per agent and per phase

### 4. Project Templates

Templates are stack-agnostic — the architect decides the stack per project. Templates are **reference guides**, not configuration files.

Each template covers:
- What a good user story looks like (examples, anti-examples)
- What a well-formed task looks like (structure, scope, strict size/dependency constraints)
- Common failure modes and how to avoid them

### 5. Self-Improvement Mechanism

**Always automatic:**
- Failures and ambiguities related to agent behavior or workflow are recorded to a journal (`artifacts/improvement-journal.md`) as they occur

**Critical issues** (agent blocked, repeated failures, workflow broken):
- Agent prompts user at each milestone: "A critical issue was found — fix now?"
- Shows exact proposed change as a diff
- User approves → agent applies directly

**Non-critical issues:**
- Queued in the journal with proposed fixes
- Reviewed between project sessions: agent presents each, user approves/rejects, applied in bulk

**Troubleshooting guide integration:**
- When any fix is applied (critical or non-critical), the problem + fix is automatically appended to `docs/troubleshooting.md`
- The guide builds itself from real experience over time

### 6. Documentation

**User guide** (`docs/user-guide.md`):
- How to start a new project
- How to invoke each agent
- How handoffs work between agents
- How to use the dashboard
- How the self-improvement mechanism works

**Per-agent how-to:**
- Covered in each agent's README (not in CLAUDE.md)
- CLAUDE.md remains operational instructions only

**Troubleshooting guide** (`docs/troubleshooting.md`):
- Initial version built during Phase 6 with known issues and edge cases
- Auto-amended by the self-improvement mechanism as real issues are resolved

---

## Q&A Session (Completed 2026-03-22)

### Integration Testing
- **Validation test:** Papertrail simulation (real project to follow separately)
- **Case study:** No

### Dashboard
- **Format:** Both terminal (per-project) and web (multi-project)
- **Views:** Running Now / Task Graph / Metrics / Audit Log
- **Multi-project:** Web version supports multiple projects via tabs; terminal launched per project

### Templates
- **Stacks:** Not hardcoded — architect decides per project
- **Content:** Guides showing what good user stories and well-formed tasks look like, with constraints

### Self-Improvement
- **Automation:** Always-on recording; critical fixes prompted at milestones with diff; non-critical batched between sessions
- **Application:** Agent applies directly after user approval (not proposals only)

### Documentation
- **User guide:** Yes
- **Per-agent how-to:** In README/user guide, not CLAUDE.md
- **Troubleshooting guide:** Built now, auto-amended from real fixes
