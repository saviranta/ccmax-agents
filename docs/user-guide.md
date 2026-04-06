# agents-max User Guide

agents-max is a 5-agent pipeline that takes a software product from idea to deployed code. Each agent has a specific role and hands off to the next via an explicit JSON file that you review before proceeding.

---

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [Pipeline Overview](#2-pipeline-overview)
3. [Agent Guide](#3-agent-guide)
4. [Handoffs](#4-handoffs)
5. [Dashboard](#5-dashboard)
6. [Self-Improvement](#6-self-improvement)
7. [Fix Mode (Builder)](#7-fix-mode-builder)
8. [Common Workflows](#8-common-workflows)
9. [Scripts Reference](#9-scripts-reference)

---

## 1. Quick Start

### Prerequisites

- **Claude Code CLI** — must be installed and authenticated (`claude --version` should work)
- **Python 3** — used by `dashboard-server.sh` and `metrics.sh` (`python3 --version`)
- **Git** — project must be a git repository before running init
- **Node.js / npm** — required if you're building a JS/TS project (Launcher runs `npm run build`)

### Initialize a New Project

```bash
bash <agents-max>/scripts/max-agents-init.sh
```

The init script is interactive. It will ask:

1. **Mode** — `new` (brand-new project) or `adopt` (existing codebase you want to bring into the pipeline)
2. **Project path** — absolute path to your project directory (must already exist and be a git repo)
3. **Project name** — human-readable name stored in `config.json`
4. **Target stack** — optional; leave blank to let the Architect decide later

**New mode** scaffolds a clean `.max-agents/` directory and writes `.claude/` settings.

**Adopt mode** does the same but also runs a brief audit of the existing codebase so the Prototyper and Architect have context.

### Validate Your Setup

After init, confirm everything looks right:

```bash
bash <agents-max>/scripts/validate.sh /path/to/your/project
```

A clean run prints `PASS` for each check. Any `FAIL` line tells you exactly what is wrong and how to fix it.

### What Gets Created

After a successful init the following structure exists inside your project:

```
<project>/
├── .max-agents/
│   ├── config.json          # project name, root path, stack (if specified), created_at
│   ├── state.json           # current pipeline stage, active_agents, milestone
│   ├── handoffs/            # JSON handoff files between agents
│   ├── artifacts/           # agent output organized by agent name
│   │   ├── prototyper/
│   │   ├── architect/
│   │   ├── builder/
│   │   └── launcher/
│   ├── audit-log/           # append-only event log (one JSON file per session)
│   └── checkpoints/         # point-in-time snapshots of state.json + handoffs
│
└── .claude/
    ├── settings.json        # Claude Code settings: network allowlist, tool permissions
    └── CLAUDE.md            # project-level instructions loaded into every agent session
```

The `.claude/CLAUDE.md` file is pre-populated with the project name, stack, and pipeline stage. Agents read it automatically when you open Claude Code in the project directory.

---

## 2. Pipeline Overview

```
  ┌────────────┐     handoff     ┌─────────────┐     handoff     ┌───────────┐
  │ Researcher │ ──────────────► │  Prototyper │ ──────────────► │ Architect │
  │ (optional) │                 │             │                 │           │
  └────────────┘                 └─────────────┘                 └─────┬─────┘
       ▲  ▲                                                             │ handoff
       │  └── called by Architect, Builder, or Launcher as needed      ▼
       │                                                         ┌─────────────┐
       └── standalone: answer a question, explore a market       │   Builder   │
                                                                 └──────┬──────┘
                                                                        │ handoff
                                                                        ▼
                                                                 ┌─────────────┐
                                                                 │  Launcher   │
                                                                 └─────────────┘
```

| Agent | What it does | When you use it |
|---|---|---|
| **Researcher** | Finds information — market research, competitor analysis, technical deep-dives | Standalone at any point, or called automatically by other agents |
| **Prototyper** | Defines the product — vision, user stories, wireframes, design constraints | Start of a new project, or when adding a feature |
| **Architect** | Designs the system — stack, ADRs, data model, API contracts, task graph | After Prototyper produces a handoff |
| **Builder** | Builds the code — dispatches sub-agents to implement the task graph | After Architect produces a handoff |
| **Launcher** | Ships the product — local verification, PR, preview deploy, production, release notes | After Builder reaches a milestone |

**Key principle: handoffs are explicit.** Each agent produces a JSON handoff file at the end of its work. You read it, check it, and decide whether to approve before the next agent starts. No agent reads another agent's output without a handoff authorizing it.

---

## 3. Agent Guide

### 3.1 Researcher

**What it does:** Answers questions and gathers information. It can browse the web, read documentation, and synthesize findings into structured reports.

**When to invoke:**
- You want to understand the market before defining a product
- The Architect needs to compare three database options
- The Builder hits a technical blocker that needs external research
- You want to audit a competitor's feature set

**Two modes:**

- **Interactive** — you talk to it directly. Ask questions, get answers, steer the research.
- **Autonomous** — called by another agent (e.g. Architect says "research Supabase RLS patterns"). It runs without interruption and saves its output.

**Input:** A question or topic. Nothing from `.max-agents/` is required.

**Output:** Research reports saved to `<workspace>/research/`. Files are named by date and topic, e.g. `2026-03-22-supabase-rls-patterns.md`.

**How to start (interactive):**

From any directory, launch the Researcher agent:

```bash
bash <agents-max>/scripts/run-agent.sh researcher
```

Or directly:

```bash
claude --append-system-prompt "$(cat <agents-max>/agents/researcher/CLAUDE.md)"
```

Then describe what you want researched.

---

### 3.2 Prototyper

**What it does:** Defines the product. It produces the artifacts that everything downstream depends on: vision, user stories, wireframes, and design constraints.

**When to invoke:** First agent on a new project. Also used when adding a feature to an existing project (use the Design Feature skill).

**Always interactive** — the Prototyper never runs autonomously. You guide every step.

**Five skills:**

| Skill | What it does |
|---|---|
| **Explore** | Open-ended ideation — helps you discover what to build |
| **Design App** | Full product design: vision → user stories → wireframes → constraints |
| **Design Feature** | Same process, scoped to a single feature in an existing product |
| **Refine Detail** | Iterate on something already produced — a specific screen, a user story, a constraint |
| **Spec from Reference** | Analyze an existing app (screenshots or URL) and produce a spec from it |

**What it needs:** Nothing from `.max-agents/` for a new project. For Design Feature or Refine Detail, it reads existing Prototyper artifacts automatically.

**What it produces** (written to `.max-agents/artifacts/prototyper/`):

```
.max-agents/artifacts/prototyper/
├── vision.md                  # product vision statement and goals
├── design-constraints.md      # technical and UX constraints
├── user-stories/
│   ├── epic-auth.md
│   ├── epic-dashboard.md
│   └── ...
└── wireframes/
    ├── screen-login.md
    ├── screen-dashboard.md
    └── ...
```

**Handoff:** The Prototyper does NOT automatically create a handoff. You must explicitly say:

```
Generate the handoff now.
```

It then creates `.max-agents/handoffs/prototyper-to-architect.json` and lists everything it produced. Review this file before proceeding.

**How to start:**

From your project directory, launch the Prototyper agent:

```bash
bash <agents-max>/scripts/run-agent.sh prototyper
```

Or directly:

```bash
claude --append-system-prompt "$(cat <agents-max>/agents/prototyper/CLAUDE.md)" --model opus
```

Tell it which skill you want to use, e.g. "Use the Design App skill" or "Use the Spec from Reference skill."

---

### 3.3 Architect

**What it does:** Designs the technical system. Takes Prototyper artifacts as input and produces everything the Builder needs: stack decisions, data model, API contracts, and a complete task graph.

**When to invoke:** After the Prototyper handoff is approved.

**What it needs:** `prototyper-to-architect.json` in `.max-agents/handoffs/`. It reads all artifacts listed in `artifacts_produced` automatically.

**Three pause gates** — the Architect stops and waits for your approval at these points:

1. **Stack selection** — it proposes the tech stack (framework, database, hosting). You approve, reject, or modify before it continues.
2. **Architecture review** — it presents the data model, API contracts, and ADRs. You review and approve.
3. **Task graph review** — it presents the full task graph (every task, its dependencies, its size, its assigned sub-agent type). You approve before it generates the handoff.

**What it produces** (written to `.max-agents/artifacts/architect/`):

```
.max-agents/artifacts/architect/
├── adr/                           # Architecture Decision Records
│   ├── ADR-001-stack-selection.md
│   ├── ADR-002-auth-approach.md
│   └── ...
├── data-model.md                  # entity definitions, relationships, schema
├── api-contracts/                 # OpenAPI or plain markdown per endpoint group
│   ├── auth-api.md
│   └── ...
├── task-graph.json                # the complete task list with dependencies
└── task-specs/                    # one .md per task with acceptance criteria
    ├── TASK-001.md
    ├── TASK-002.md
    └── ...
```

**Handoff:** After gate 3 approval the Architect creates `.max-agents/handoffs/architect-to-builder.json`.

**How to start:**

From your project directory, launch the Architect agent:

```bash
bash <agents-max>/scripts/run-agent.sh architect
```

Or directly:

```bash
claude --append-system-prompt "$(cat <agents-max>/agents/architect/CLAUDE.md)" --model opus
```

The Architect will confirm it found the Prototyper handoff and begin. If it cannot find the handoff it will tell you and stop.

---

### 3.4 Builder

**What it does:** Implements the task graph. It reads `task-graph.json`, then dispatches up to 20+ specialized sub-agents in parallel — each working on an independent task. It manages dependencies, retries failures, and parks tasks that cannot be resolved.

**When to invoke:** After the Architect handoff is approved.

**What it needs:** `architect-to-builder.json` in `.max-agents/handoffs/`, and the full `artifacts/architect/` directory.

**Milestone targeting:** At startup the Builder asks which milestone to build to:

- `mvp` — minimum viable product (core features only)
- `v1` — first full release
- `v2` — extended feature set

It stops automatically when the milestone boundary is reached.

**Sub-agent dispatch:** The Builder is a coordinator. Each task in `task-graph.json` is executed by a specialized sub-agent matched to the task type (e.g. frontend-builder, api-builder, db-builder, test-writer, bug-fixer). Sub-agents run in parallel where the dependency graph allows.

**Fix Mode:** See [Section 7](#7-fix-mode-builder).

**What it produces** (written to `.max-agents/artifacts/builder/`):

```
.max-agents/artifacts/builder/
├── run-report.md          # summary: completed, parked, failed, time elapsed
└── build-index.md         # index of all files created or modified, by task
```

**Handoff:** After reaching the milestone boundary the Builder creates `.max-agents/handoffs/builder-to-launcher.json`.

**How to start:**

From your project directory, launch the Builder agent:

```bash
bash <agents-max>/scripts/run-agent.sh builder
```

Or directly:

```bash
claude --append-system-prompt "$(cat <agents-max>/agents/builder/CLAUDE.md)" --model opus
```

State your target milestone: "Build to mvp" or "Build to v1."

---

### 3.5 Launcher

**What it does:** Ships the product. Strictly sequential — every step requires your explicit approval before proceeding. Never autonomous.

**When to invoke:** After the Builder handoff is approved and you are ready to deploy.

**What it needs:** `builder-to-launcher.json` in `.max-agents/handoffs/`.

**Six sequential steps:**

1. **Local Verification** — runs `npm run build` (or equivalent), runs the test suite, checks for missing env vars. Produces `verification-report.md`.
2. **PR Creation** — creates a GitHub pull request with the build index and run report attached.
3. **Preview Deploy** — deploys to Vercel (or configured preview environment). Runs smoke tests against the preview URL.
4. **Production Deploy** — promotes preview to production after your approval.
5. **DB Migrations** — if the stack uses Supabase, runs any pending migrations. Skipped otherwise.
6. **Release Notes** — generates a `RELEASE.md` from the task graph, completed tasks, and handoff decisions.

Each step produces a log file in `.max-agents/artifacts/launcher/`.

**How to start:**

From your project directory, launch the Launcher agent:

```bash
bash <agents-max>/scripts/run-agent.sh launcher
```

Or directly:

```bash
claude --append-system-prompt "$(cat <agents-max>/agents/launcher/CLAUDE.md)" --model sonnet
```

The Launcher will confirm the Builder handoff exists and walk you through each step one at a time.

---

## 4. Handoffs

### What a Handoff File Contains

Every handoff file is a JSON object. Example (`prototyper-to-architect.json`):

```json
{
  "id": "handoff-prototyper-to-architect-20260322-141500",
  "from": "prototyper",
  "to": "architect",
  "timestamp": "2026-03-22T14:15:00Z",
  "status": "pending",
  "artifacts_produced": [
    ".max-agents/artifacts/prototyper/vision.md",
    ".max-agents/artifacts/prototyper/design-constraints.md",
    ".max-agents/artifacts/prototyper/user-stories/epic-auth.md",
    ".max-agents/artifacts/prototyper/wireframes/screen-login.md"
  ],
  "decisions_made": [
    "Product targets B2B SaaS buyers, not consumers",
    "Auth is email+password only in MVP, OAuth deferred to v1",
    "Mobile is read-only in MVP, full mobile in v1"
  ],
  "open_questions": [
    "Pricing model not finalized — architect should flag any cost-sensitive stack choices",
    "Export format for reports TBD — may affect data model"
  ],
  "review": {
    "approved_by": null,
    "approved_at": null,
    "notes": ""
  }
}
```

### How to Review a Handoff

1. Open the handoff file: `.max-agents/handoffs/<name>.json`
2. Read `artifacts_produced` — open each file and confirm it contains real content
3. Read `decisions_made` — confirm these match what you agreed on
4. Read `open_questions` — decide how to handle each before the next agent starts

### How to Approve

Tell the next agent you've reviewed the handoff:

```
I've reviewed the handoff. Proceed.
```

The agent will update `review.approved_by` and `review.approved_at` in the handoff file and begin.

### How to Reject

Before approving, tell the producing agent what is wrong:

```
The wireframes for the dashboard are missing. Add them before generating the handoff.
```

The agent will produce the missing artifacts and regenerate the handoff file. A new `id` and `timestamp` are written. Review again.

---

## 5. Dashboard

### Terminal Dashboard

A full-screen terminal UI. Works over SSH. Auto-refreshes every 5 seconds.

```bash
bash <agents-max>/scripts/dashboard.sh /path/to/project
```

**Keys:**

| Key | View |
|---|---|
| `1` | Running Now — active agents, current tasks, recent events |
| `2` | Task Graph — task list with status, dependencies, and sub-agent assignments |
| `3` | Metrics — task completion rate, time elapsed, velocity estimates |
| `4` | Audit Log — last N events from the append-only audit log |
| `q` | Quit |

The dashboard reads `state.json`, `task-graph.json`, and the audit log directory. It does not write anything.

### Web Dashboard

A browser-based dashboard. Supports multiple projects simultaneously (one tab per project).

```bash
bash <agents-max>/scripts/dashboard-server.sh /path/to/project1 /path/to/project2
```

Then open: `http://localhost:8787`

The server polls each project's `.max-agents/` directory and writes `dashboard/data/snapshot.json` every few seconds. The browser reads that file. If `snapshot.json` is not being written, the browser shows "Loading..." — this means the server is not running.

Same four views as the terminal dashboard, with a richer layout: color-coded task graph, clickable tasks for detail, timeline chart on the Metrics view.

---

## 6. Self-Improvement

The system tracks issues and fixes as it runs. `improvement.sh` is the interface.

### Record an Issue

Use this during any session when something goes wrong or could be better:

```bash
bash <agents-max>/scripts/improvement.sh record /path/to/project critical workflow "Builder stalls when all remaining tasks depend on a parked task"
```

Severity levels: `critical`, `high`, `medium`, `low`

Categories: `workflow`, `output-quality`, `performance`, `ux`, `security`

Critical issues block milestone advancement. The Builder will not generate a handoff until all critical issues are either resolved or explicitly overridden.

### Propose a Fix

After recording an issue, propose how to fix it:

```bash
bash <agents-max>/scripts/improvement.sh propose /path/to/project ENTRY-001 "Change task-graph generation to detect blocked clusters and surface them to the user instead of stalling silently"
```

### Milestone Check

Agents call this automatically at milestone boundaries. You can also call it manually:

```bash
bash <agents-max>/scripts/improvement.sh milestone-check /path/to/project
```

Prints all open issues, grouped by severity. If any critical issues exist, it exits non-zero.

### Apply a Fix

Once you've made a code or config change that resolves an issue:

```bash
bash <agents-max>/scripts/improvement.sh apply /path/to/project ENTRY-001
```

This marks the issue as resolved and **automatically appends an entry to `docs/troubleshooting.md`** with the problem description, root cause, and fix applied.

### Review the Backlog

See all non-critical issues waiting for attention:

```bash
bash <agents-max>/scripts/improvement.sh review /path/to/project
```

---

## 7. Fix Mode (Builder)

Fix Mode lets you send feedback to the Builder during or after a build run — without restarting the pipeline.

### How to Use It

1. Create the feedback inbox if it doesn't exist:

   ```bash
   mkdir -p /path/to/project/feedback/inbox
   ```

2. Drop one or more files into the inbox:

   ```
   /path/to/project/feedback/inbox/
   ├── screenshot-dashboard-layout.png   # a screenshot of what looks wrong
   ├── failing-test-output.txt           # paste of a test failure
   └── note-missing-export-button.txt    # plain text description
   ```

3. Tell the Builder:

   ```
   Process feedback.
   ```

   Or: `Fix mode.`

### How the Builder Classifies Feedback

| Feedback type | Builder action |
|---|---|
| Bug or visual polish | Adds a new task to the task graph and implements it |
| UX issue | Routes back to Prototyper for a design decision before implementing |
| Missing feature (small) | Adds a SCOPE+ task, flags for your approval |
| Missing feature (large) | Routes to Architect to extend the task graph |

SCOPE+ tasks require your explicit approval before the Builder implements them. The Builder will list them and wait.

---

## 8. Common Workflows

### New Project from Scratch

```bash
# 1. Create your project directory and initialize git
mkdir /path/to/myapp && cd /path/to/myapp
git init

# 2. Run agents-max init
bash <agents-max>/scripts/max-agents-init.sh
# Choose: new, /path/to/myapp, "My App", (leave stack blank)

# 3. Validate
bash <agents-max>/scripts/validate.sh /path/to/myapp

# 4. Open Claude Code in the project and run agents in sequence
# /prototyper  →  /architect  →  /builder  →  /launcher
```

### Add a Feature to an Existing Project

If the project is already in the pipeline (has `.max-agents/`):

```bash
# Open Claude Code in the project
/prototyper
# Use the "Design Feature" skill
# When done, generate handoff
# Then: /architect (it extends the existing task graph)
# Then: /builder (builds only the new tasks)
```

If the project is not yet in the pipeline:

```bash
bash <agents-max>/scripts/max-agents-init.sh
# Choose: adopt, /path/to/existing-project
```

### Debug a Build Failure

```bash
# 1. Check the build summary
open /path/to/project/.max-agents/artifacts/builder/run-report.md

# 2. Open the terminal dashboard and switch to Audit Log view
bash <agents-max>/scripts/dashboard.sh /path/to/project
# Press 4

# 3. Drop the failing output into feedback inbox and let Builder fix it
mkdir -p /path/to/project/feedback/inbox
# Copy failing test output or error log into inbox/
# Open Claude Code, run /builder, say "Process feedback"
```

### Check Pipeline Health at Any Point

```bash
bash <agents-max>/scripts/validate.sh /path/to/project
```

A clean run confirms: config exists, state is consistent, all handoff artifacts are present, task graph has no cycles or missing dependencies.

---

## 9. Scripts Reference

| Script | Usage | What it does |
|---|---|---|
| `max-agents-init.sh` | `bash max-agents-init.sh` | Interactive setup. Creates `.max-agents/` and `.claude/` in a project directory. |
| `validate.sh` | `bash validate.sh <project-path>` | Validates config, state, handoffs, and task graph. Prints PASS/FAIL per check. |
| `audit-log.sh` | `bash audit-log.sh <project-path> log <agent> <event-type> <message>` | Appends a structured event to the audit log. Called by agents, rarely by hand. |
| `checkpoint.sh` | `bash checkpoint.sh <project-path> create <label>` | Creates a named snapshot of state.json and handoffs. Use before risky operations. |
| `checkpoint.sh` | `bash checkpoint.sh <project-path> restore <label>` | Restores a previous snapshot. |
| `security-audit.sh` | `bash security-audit.sh <project-path>` | Checks for hardcoded secrets, insecure dependencies, and dangerous tool permissions in `.claude/settings.json`. |
| `dashboard.sh` | `bash dashboard.sh <project-path>` | Full-screen terminal dashboard. Keys 1-4 for views, q to quit. |
| `dashboard-server.sh` | `bash dashboard-server.sh <project-path> [<project-path2> ...]` | HTTP server for web dashboard at localhost:8787. Supports multiple projects. |
| `metrics.sh` | `bash metrics.sh <project-path>` | Prints task completion stats, velocity, and time estimates to stdout. |
| `improvement.sh` | `bash improvement.sh <project-path> <subcommand> [args]` | Records issues, proposes fixes, checks milestone gates, applies approved fixes. Subcommands: `record`, `propose`, `milestone-check`, `apply`, `review`. |

---

_End of user guide._
