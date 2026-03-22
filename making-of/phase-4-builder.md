# Phase 4: Builder

**Status:** Q&A complete — ready for implementation

## Overview

The Builder is the autonomous execution engine of the pipeline. It takes the Architect's task graph and builds the entire application — running cognitively specialised worker agents in parallel, with integrated review, testing, and fix cycles. Designed for long autonomous runs without human involvement. The user starts it, picks a target milestone, and returns to a completed build.

## Why Phase 4

The Builder is the core value proposition of the system — autonomous builds. It depends on the Architect's output (Phase 3) and is the most technically complex component. Getting everything right means the user can walk away and come back to working software.

## Architecture

```
BUILDER (Opus orchestrator)
│
├── CORE BUILDERS (parallel, any type can have multiple instances)
│   ├── builder-composer
│   ├── builder-systems
│   ├── builder-data
│   ├── builder-integration
│   ├── builder-ui
│   └── builder-infra
│
├── CONDITIONAL BUILDERS (dispatched when project needs them)
│   ├── builder-ml
│   ├── builder-realtime
│   ├── builder-mobile
│   └── builder-api
│
├── QUALITY GATE — per task
│   ├── convention-checker    (runs first, before code review)
│   └── reviewer-code
│
├── QUALITY GATE — phase boundary (parallel)
│   ├── reviewer-security
│   └── reviewer-design
│
├── CONDITIONAL REVIEWERS
│   ├── reviewer-accessibility
│   ├── reviewer-performance
│   ├── reviewer-api-design
│   ├── reviewer-typescript
│   └── reviewer-python  (extensible)
│
├── TESTING — per task
│   └── tester-unit
│
├── TESTING — phase gates
│   └── tester-integration
│
├── TESTING — milestone boundaries
│   └── tester-e2e
│
├── CONDITIONAL TESTERS
│   ├── tester-visual
│   ├── tester-performance
│   ├── tester-accessibility
│   └── tester-contract
│
├── SUPPORT
│   ├── bug-fixer
│   ├── mini-architect
│   └── screenshot-analyzer   (fix mode only)
│
└── [TODO: notification-agent — Telegram/push notifications stub, not implemented]
```

## Concurrency Model

**Critical rule — explicit and prominent:**

Any agent type can have multiple instances running simultaneously. The orchestrator may dispatch ten `builder-composer` instances, five `bug-fixer` instances, or three `tester-unit` instances at the same time if there is work for them. The same applies to every agent type in the system — builders, reviewers, testers, and support agents alike.

The only hard constraint: **no two agent instances of any type may own the same file concurrently.** File ownership is the sole parallelism gate.

The orchestrator achieves this by using the Agent tool with multiple simultaneous tool calls in a single response — all calls dispatch in parallel, orchestrator waits for all to return, then processes results and dispatches the next batch. Up to 20+ agents can run simultaneously this way. There is no artificial cap.

## Execution Model

### Build Loop

```
┌─────────────────────────────────────────────────────────────┐
│                        BUILD LOOP                            │
│                                                              │
│  STARTUP                                                     │
│  1. Read task-graph.json from artifacts/architect/           │
│  2. Ask user: "Build to which milestone? MVP / V1 / V2 / all"│
│  3. Activate conditionals: scan task-graph.json `requires`   │
│     fields + .max-agents/config.json stack declaration       │
│  4. Validate: no [SCOPE+] tasks remain (resolved pre-build)  │
│                                                              │
│  BATCH DISPATCH (repeat until milestone reached or blocked)  │
│  5. Find all tasks: status=pending, deps all done            │
│  6. Pre-flight: verify no file ownership conflicts in batch  │
│  7. Route L tasks → mini-architect (splits to M/S first)     │
│  8. Assign auto tasks → orchestrator judgment + log          │
│  9. Dispatch entire batch as parallel Agent tool calls       │
│     Each worker runs in isolated git worktree                │
│                                                              │
│  PER-TASK COMPLETION PIPELINE (for each returning worker)    │
│  10. convention-checker → if fail → bug-fixer               │
│  11. reviewer-code → if NEEDS_CHANGES → bug-fixer           │
│  12. tester-unit → if fail → bug-fixer                      │
│  13. All pass → merge worktree to phase branch               │
│  14. Update task-graph.json status → pending next tasks      │
│                                                              │
│  PHASE BOUNDARY (when all tasks in a phase complete)         │
│  15. tester-integration → if fail → mini-architect + fix     │
│  16. reviewer-security + reviewer-design (parallel)          │
│  17. Conditional reviewers if active for project             │
│  18. All pass → phase branch ready, begin next phase         │
│                                                              │
│  MILESTONE BOUNDARY                                          │
│  19. tester-e2e → full user journeys                         │
│  20. If target milestone reached → graceful stop             │
│                                                              │
│  EXIT CONDITIONS                                             │
│  - Target milestone reached                                  │
│  - All remaining tasks blocked or parked                     │
│  - User interrupt                                            │
│  → Write run-report.md + build-index.md on any exit          │
└─────────────────────────────────────────────────────────────┘
```

### Worktree Isolation

Each worker operates in its own git worktree, created automatically via `isolation: "worktree"` in the Agent tool:

```
project-root/
├── src/                         # Main working tree
└── .worktrees/                  # Managed by Builder orchestrator
    ├── task-001/                # builder-infra's worktree
    ├── task-002/                # builder-ui's worktree
    └── task-003/                # builder-systems's worktree
```

After a task passes all per-task gates, its worktree is merged into the phase branch (`max-agents/phase-N`). Merge conflicts → mini-architect resolves.

### Git Workflow

- **Per task:** temporary worktree branch (auto-created + auto-cleaned by `isolation: "worktree"`)
- **Per phase:** persistent phase branch — `max-agents/phase-1`, `max-agents/phase-2`, etc. Task worktrees merge here after passing review.
- **Main:** untouched during build. Phase branches are left for the Launcher to PR into main.
- **Commit format:** `[task-003] Create UserProfile component`

### L Task Splitting

L-sized tasks (5 files, complex logic) never go directly to a builder worker:

1. Orchestrator detects L task in batch
2. Dispatches `mini-architect` to decompose it into M/S sub-tasks
3. Mini-architect produces sub-tasks with explicit file ownership, adds them to task-graph.json
4. Decomposition logged to `artifacts/builder/mini-architect-log.md`
5. Sub-tasks re-enter the batch dispatch loop normally

### Task Assignment Model

The Architect pre-assigns tasks in three ways:
- `assigned_to: "builder-data"` — clear cognitive fit, Architect decides
- `assigned_to: "auto"` — ambiguous, Builder orchestrator decides at runtime and logs choice
- `requires: ["realtime"]` — flags conditional builder needed, orchestrator picks the instance

Each task also has:
- `may_need: ["researcher", "reviewer-typescript"]` — Architect's hint for likely support agents
- **One owner, unlimited support:** the assigned builder owns the task and output files. It may request support from any helper agent mid-execution via the orchestrator. Helpers are consulted, not co-owners.

### Bug-Fix Cycle

Severity-relative attempt limits:
- **Critical** (security issue, data corruption, broken core flow): 5 attempts
- **Standard** (incorrect behaviour, failed test): 3 attempts
- **Polish** (styling drift, minor UX): 2 attempts

Counter never resets regardless of what new issues appear during fixing. After max attempts: task parked with full attempt history logged.

### Stall Detection

| Condition | Action |
|-----------|--------|
| Worker produces no output for 10 min | Kill, requeue task |
| Task exceeds max fix attempts | Park task, log reason |
| No progress across entire batch | Pause, write run-report, alert user |

### Notifications

```
# TODO: notification-agent
# Wire in Telegram / push / other channel here when ready
# Trigger points: build complete, milestone reached, all tasks blocked
# Current behaviour: writes run-report.md on any exit condition
```

### Fix Mode

Activated by user command: `"process feedback"` or `"fix mode"` in the Builder terminal.

**Input methods:**
- Natural language typed directly in terminal
- Files dropped into `.max-agents/artifacts/feedback/inbox/` (screenshots, text notes) — processed when user says "process feedback"
- Screenshots analysed by `screenshot-analyzer` sub-agent (extracts what's wrong visually)

**Triage routing:**
- `bug` / `polish` → `bug-fixer` handles directly, same build → review → test cycle
- `ux-issue` → parks item, tells user to start Prototyper to resolve design question first
- `missing-feature` → parks item, tells user to start Architect to decompose and plan it

**Execution:**
- Fix tasks added to existing task-graph.json (not a separate graph)
- Same pipeline as build mode: convention-checker → reviewer-code → tester-unit
- Parked items listed with clear routing guidance

**Feedback storage:**
```
.max-agents/artifacts/feedback/
├── inbox/              # Raw input: screenshots, text files dropped by user
├── session-NNN.md      # Structured feedback log per fix session
└── index.md            # Index of all feedback sessions
```

## Human-in-the-Loop

| Step | Human Action | Agent Action |
|------|-------------|--------------|
| Start | Confirm Architect handoff received, pick target milestone | Validate task graph, activate conditionals from task-graph.json `requires` fields + config.json, begin build loop |
| During (optional) | Check run-report anytime | Continue building autonomously |
| Blocked | Resolve parked tasks (merge conflict, missing config, ux-issue) | Resume after human unblocks |
| Exit | Review run-report + build-index, test the build | Write handoff to Launcher |
| Fix mode | Type feedback or drop files into inbox | Triage, fix, report parked items |

The Builder is designed for **zero human interaction during normal operation.** Human involvement only at: start (milestone selection), blockers (resolution), and exit (review).

---

## Output Format

### Directory Structure

```
artifacts/builder/
├── run-report.md            # What was built, errors, final task graph state, mini-architect decisions summary
├── build-index.md           # What exists: features, components, APIs, key file locations, milestone reached, known issues, how to run
├── mini-architect-log.md    # Append-only log of all mini-architect decisions
└── feedback/                # Fix mode
    ├── inbox/               # Raw input: screenshots, text files dropped by user
    ├── session-NNN.md       # Structured feedback log per fix session
    └── index.md             # Index of all feedback sessions
```

Phase branches in git: `max-agents/phase-1`, `max-agents/phase-2`, etc.

### run-report.md Structure

```markdown
# Builder Run Report

## Run Summary
- Started: [timestamp]
- Stopped: [timestamp]
- Exit reason: [milestone_reached | all_blocked | user_interrupt]
- Target milestone: MVP
- Milestone reached: MVP ✓

## Tasks
- Completed: 34
- Parked: 2
- Failed (max attempts): 1

## Parked Tasks
| Task | Reason | Routing |
|------|--------|---------|
| task-035 | Merge conflict in src/utils/format.ts | Resolve manually, re-run Builder |
| task-041 | Missing STRIPE_API_KEY | Add to .env, re-run Builder |

## Mini-Architect Decisions
3 decisions made — see mini-architect-log.md for full detail

## Phase Summary
| Phase | Status | Integration Tests |
|-------|--------|------------------|
| phase-1 | ✓ complete | ✓ passed |
| phase-2 | ✓ complete | ✓ passed |
```

### build-index.md Structure

```markdown
# Build Index

## Milestone Reached
MVP — core functionality built

## What Was Built
### Features
- User authentication (Google OAuth)
- Dashboard with real-time data
- User profile management

### Key Files
- Entry point: src/app/page.tsx
- Auth: src/lib/auth.ts
- API routes: src/app/api/
- Database: src/db/

## How to Run
\`\`\`bash
npm install
cp .env.example .env  # fill in required values
npm run dev
\`\`\`

## Environment Variables Required
- DATABASE_URL
- NEXTAUTH_SECRET
- GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET

## Known Issues / Parked Tasks
- task-035: merge conflict needs manual resolution
- task-041: Stripe integration incomplete (missing API key)
```

### Handoff to Launcher

Follows Phase 0 handoff protocol — `handoffs/builder-to-launcher.json`:

```json
{
  "id": "handoff-003",
  "from": "builder",
  "to": "launcher",
  "timestamp": "2026-03-22T18:00:00Z",
  "milestone_reached": "mvp",
  "artifacts_produced": [
    "artifacts/builder/run-report.md",
    "artifacts/builder/build-index.md"
  ],
  "phase_branches": ["max-agents/phase-1", "max-agents/phase-2"],
  "parked_tasks": ["task-035", "task-041"],
  "open_questions": [],
  "recommended_next_steps": [
    "Resolve parked tasks before deploying",
    "Review run-report for any quality gate warnings"
  ]
}
```

---

## Agent Definitions

### Design Principle: Simultaneous Multi-Instance Dispatch

Any agent type can have multiple instances running simultaneously. The orchestrator assigns each instance a non-overlapping file set before dispatch. No two agent instances ever own the same output file. This is the foundation of the parallel build model.

---

### Builder (Orchestrator)

- **Model:** Opus
- **Tools:** All
- **Cognitive Mode:** Coordination — manages the build loop, never builds anything itself
- **Role:** Reads the task graph, manages batch dispatch (multiple simultaneous Agent tool calls in a single response, enabling 20+ parallel agents), routes L tasks through mini-architect, tracks file ownership across all running agent instances, manages worktrees, runs quality gates, and writes run-report and build-index on exit.
- **Key behavior:** Pure coordination. Never writes application code. Multiple instances of any agent type may run simultaneously — before dispatching any batch, the orchestrator partitions output files into non-overlapping sets and assigns one set per agent instance. Two instances of `builder-ui` may run at once, but they will never touch the same file. Sole writer of `task-graph.json` status fields.
- **Owns files:** `task-graph.json` (status fields), `artifacts/builder/run-report.md`, `artifacts/builder/build-index.md`

---

### CORE BUILDERS

All core builders:

- **Model:** Sonnet
- **Tools:** Read, Write, Edit, Bash (build/test tools only), Glob, Grep
- **Shared rules:** Multiple instances of the same builder type may run simultaneously — each owns a distinct non-overlapping file set assigned by the orchestrator. One owner per task: the assigned builder owns the output files. Can request support from helper agents via orchestrator — helpers are consulted, not co-owners.

---

### builder-composer

- **Cognitive Mode:** Orchestration thinking — how do existing pieces connect into a complete feature?
- **Role:** Wires existing components, services, and utilities into working features. Thinks about user flow, data flow between layers, and connecting frontend to backend.
- **Key behavior:** Reads widely (existing components, API contracts, state management), writes the glue code that makes features work end to end. Does not create new primitives — composes what already exists.
- **Owns files:** Feature integration files, route handlers, page-level components, service orchestration layers.

---

### builder-systems

- **Cognitive Mode:** Design thinking — what's the cleanest primitive with the right interface?
- **Role:** Creates new reusable components, services, and utilities from scratch. Thinks about API design, reusability, and clean interfaces.
- **Key behavior:** Writes foundational pieces that other builders will depend on. Prioritises clean interfaces over implementation cleverness. Considers how downstream consumers will use the primitive.
- **Owns files:** Shared utilities, base components, service abstractions, core libraries.

---

### builder-data

- **Cognitive Mode:** Relational thinking — what are the data relationships, constraints, and integrity rules?
- **Role:** Implements schema, migrations, queries, and data access layer from the Architect's `data-model.md`. Never generates schema files from scratch — translates architect markdown specs into code.
- **Key behavior:** Correctness above all. Every query considers edge cases. Schema changes require an explicit approval flag in the task spec. Thinks about indexes, constraints, cascading behaviour, and data integrity at every step.
- **Owns files:** Schema definitions, migration files, query builders, repository/DAO layers, seed data.

---

### builder-integration

- **Cognitive Mode:** Defensive thinking — what can go wrong with this external system?
- **Role:** Implements third-party API clients, webhooks, OAuth flows, and external service connections.
- **Key behavior:** Defensive error handling mandatory. Zod/equivalent validation on all external responses. Never hardcodes secrets. Assumes external systems will fail — implements retries, circuit breakers, and graceful degradation as appropriate.
- **Owns files:** API client modules, webhook handlers, OAuth flow implementations, external service adapters.

---

### builder-ui

- **Cognitive Mode:** Visual thinking — does this match the design system and feel right to use?
- **Role:** Implements UI components with focus on design system compliance, accessibility, interaction states (hover, focus, loading, error, empty), and responsive behaviour.
- **Key behavior:** Reads `design-system.md` and Storybook stubs before writing. Runs `tsc --noEmit` before declaring done. Checks all interaction states are handled. Multiple instances may run simultaneously on different component sets.
- **Owns files:** UI components, stylesheets/styled components, Storybook stories, component-level tests.

---

### builder-infra

- **Cognitive Mode:** Operational thinking — will this work reliably across all environments?
- **Role:** Project scaffolding, build config, CI/CD, Docker, environment setup, package management.
- **Key behavior:** Documents all environment variables. Must not install packages not specified in architecture docs. Thinks about dev/staging/prod differences and ensures configuration works across all environments.
- **Owns files:** Dockerfiles, CI/CD configs, build scripts, environment templates, package manifests.

---

### CONDITIONAL BUILDERS

Same model and tools as core builders. Dispatched by orchestrator based on project characteristics from Architect artifacts. Multiple instances allowed simultaneously, each with non-overlapping file sets.

---

### builder-ml

- **Cognitive Mode:** ML pipeline thinking — data in, model out, serving strategy
- **Role:** ML model integration, data pipelines, model serving, training infrastructure requirements.
- **Dispatched when:** Project includes ML/data science components.
- **Owns files:** Model definitions, data pipeline scripts, serving endpoints, training configs.

---

### builder-realtime

- **Cognitive Mode:** Event-driven thinking — connections, state sync, race conditions
- **Role:** WebSocket handlers, event-driven systems, pub/sub, presence, conflict resolution.
- **Dispatched when:** Project requires real-time features.
- **Owns files:** WebSocket handlers, event emitters/listeners, pub/sub adapters, presence tracking modules.

---

### builder-mobile

- **Cognitive Mode:** Mobile platform thinking — constraints, offline, native capabilities
- **Role:** React Native / native mobile code, offline strategy, push notification implementation, app store requirements.
- **Dispatched when:** Project includes mobile targets.
- **Owns files:** Mobile screens, native modules, offline storage layers, push notification handlers.

---

### builder-api

- **Cognitive Mode:** API product thinking — developer experience, versioning, contracts
- **Role:** Public-facing API implementation, SDK generation, API versioning, rate limiting implementation.
- **Dispatched when:** Project builds a public API product.
- **Owns files:** API route handlers, middleware, SDK templates, rate limiting modules, API documentation generators.

---

### QUALITY GATE — PER TASK

These agents run in sequence after every task completes: convention-checker first, then reviewer-code. Multiple instances run simultaneously for parallel tasks — one instance per task, each reviewing that task's non-overlapping file set.

---

### convention-checker

- **Model:** Haiku
- **Tools:** Read, Write
- **Cognitive Mode:** Compliance verification — does this output follow every stated convention?
- **Role:** Runs after every task completes, before reviewer-code. Reads `conventions.md` and task output, verifies compliance. Violations flagged to bug-fixer before code reviewer sees the output.
- **Key behavior:** This is a gate, not a suggestion. Runs first in the per-task quality pipeline to ensure reviewer-code works on convention-clean code. Multiple instances run simultaneously for parallel tasks.
- **Owns files:** None (reads `conventions.md`, writes violation notes to task status).

---

### reviewer-code

- **Model:** Sonnet
- **Tools:** Read, Glob, Grep (NO Edit, NO Write, NO Bash — read-only)
- **Cognitive Mode:** Correctness thinking — is this code right, clear, and maintainable?
- **Role:** Reviews every task after convention-checker passes. Checks correctness, patterns, naming, complexity, dead code, missing error handling.
- **Verdicts:** `PASS` / `NEEDS_CHANGES` (with specific fix instructions) / `FAIL` (unfixable by agent)
- **Key behavior:** Read-only access enforced. Multiple instances run simultaneously for parallel tasks.

---

### QUALITY GATE — PHASE BOUNDARY

Both run in parallel at phase boundary after all phase tasks complete. Broader-scope reviews covering entire phase output, not individual tasks.

---

### reviewer-security

- **Model:** Sonnet
- **Tools:** Read, Glob, Grep (read-only)
- **Cognitive Mode:** Adversarial thinking — how would an attacker exploit this?
- **Role:** Reviews entire phase output at phase boundary. OWASP checks, injection risks, auth bypass, secret exposure, insecure dependencies, CORS/CSP.
- **Verdicts:** `PASS` / `NEEDS_CHANGES` / `FAIL`
- **Key behavior:** Thinks like an attacker. Multiple instances may run simultaneously across different phases.

---

### reviewer-design

- **Model:** Sonnet
- **Tools:** Read, Glob, Grep (read-only)
- **Cognitive Mode:** Design system thinking — does this phase's UI output match the system?
- **Role:** Reviews entire phase output at phase boundary. Design system compliance, responsive behaviour, accessibility basics.
- **Verdicts:** `PASS` / `DRIFT` (minor deviations) / `BROKEN` (major violations)
- **Key behavior:** Compares implemented UI against `design-system.md`. Multiple instances may run simultaneously across different phases.

---

### CONDITIONAL REVIEWERS

Dispatched when project characteristics require them. Read-only access. Multiple instances allowed simultaneously.

---

### reviewer-accessibility

- **Model:** Sonnet
- **Tools:** Read, Glob, Grep (read-only)
- **Cognitive Mode:** Inclusive design thinking — can everyone use this?
- **Role:** WCAG compliance review, screen reader compatibility, keyboard navigation, colour contrast.
- **Dispatched when:** Project has accessibility requirements (UI projects).

---

### reviewer-performance

- **Model:** Sonnet
- **Tools:** Read, Glob, Grep (read-only)
- **Cognitive Mode:** Performance thinking — where are the bottlenecks and anti-patterns?
- **Role:** Identifies performance anti-patterns, N+1 queries, unnecessary re-renders, missing indexes, large bundle sizes.
- **Dispatched when:** Project has explicit performance requirements.

---

### reviewer-api-design

- **Model:** Sonnet
- **Tools:** Read, Glob, Grep (read-only)
- **Cognitive Mode:** API product thinking — is this API consistent, versioned, and developer-friendly?
- **Role:** API consistency, naming conventions, versioning strategy, error response shapes, documentation completeness.
- **Dispatched when:** Project builds a public API product.

---

### reviewer-typescript

- **Model:** Sonnet
- **Tools:** Read, Glob, Grep (read-only)
- **Cognitive Mode:** TypeScript idiom thinking — is this idiomatic, type-safe, and correct TS?
- **Role:** TypeScript-specific review — strict mode compliance, type safety, generics usage, React patterns, module structure.
- **Dispatched when:** Project uses TypeScript.

---

### reviewer-python

- **Model:** Sonnet
- **Tools:** Read, Glob, Grep (read-only)
- **Cognitive Mode:** Pythonic thinking — is this idiomatic, well-typed Python?
- **Role:** Python-specific review — type hints, async patterns, Pythonic idioms, dependency management, test structure.
- **Dispatched when:** Project uses Python.
- **Note:** Extensible — add `reviewer-swift`, `reviewer-go`, `reviewer-rust` etc. following the same pattern.

---

### TESTING

All testers share the same model. Multiple instances run simultaneously for parallel tasks unless otherwise noted.

---

### tester-unit

- **Model:** Sonnet
- **Tools:** Read, Bash (test runners only), Glob, Grep
- **Cognitive Mode:** Unit verification — does this unit behave as specified?
- **Role:** Runs unit tests for changed files after reviewer-code passes. Reports `PASS` / `FAIL` with failure details.
- **Key behavior:** Runs existing test suites against task output. Does not write tests — validates that builder-written tests pass.

---

### tester-integration

- **Model:** Sonnet
- **Tools:** Read, Bash, Glob, Grep
- **Cognitive Mode:** Integration verification — do the parts connect correctly?
- **Role:** Runs integration tests at phase gates. Verifies inter-component contracts. Must pass before next phase activates.
- **Key behavior:** Tests cross-boundary interactions — API-to-database, service-to-service, frontend-to-backend.

---

### tester-e2e

- **Model:** Sonnet
- **Tools:** Read, Bash, Glob, Grep
- **Cognitive Mode:** User journey verification — does the complete flow work?
- **Role:** Runs Playwright/Cypress tests at milestone boundaries (MVP, V1, V2). Tests full user journeys end to end.
- **Reports:** `PASS` / `PARTIAL` (some journeys pass) / `FAIL`

---

### CONDITIONAL TESTERS

Dispatched when project characteristics require them. Multiple instances allowed simultaneously.

---

### tester-visual

- **Model:** Sonnet
- **Tools:** Read, Bash, Glob, Grep
- **Cognitive Mode:** Visual regression verification — does the rendered output match the baseline?
- **Role:** Screenshot regression testing — compares rendered output against baseline screenshots.
- **Dispatched when:** UI-heavy projects with visual regression requirements.

---

### tester-performance

- **Model:** Sonnet
- **Tools:** Read, Bash, Glob, Grep
- **Cognitive Mode:** Load verification — does the system meet its performance SLAs?
- **Role:** Load and stress testing. Verifies performance requirements from architecture docs.
- **Dispatched when:** Project has explicit performance SLAs.

---

### tester-accessibility

- **Model:** Sonnet
- **Tools:** Read, Bash, Glob, Grep
- **Cognitive Mode:** Automated accessibility verification — do the automated checks pass?
- **Role:** Automated accessibility testing via axe-core or equivalent. Complements reviewer-accessibility with automated checks.
- **Dispatched when:** UI projects with accessibility requirements.

---

### tester-contract

- **Model:** Sonnet
- **Tools:** Read, Bash, Glob, Grep
- **Cognitive Mode:** Contract verification — does the implementation match the spec?
- **Role:** API contract testing — verifies implementation matches OpenAPI spec from Architect.
- **Dispatched when:** Project has public API products.

---

### SUPPORT AGENTS

---

### bug-fixer

- **Model:** Sonnet
- **Tools:** Read, Write, Edit, Bash, Glob, Grep
- **Cognitive Mode:** Diagnostic thinking — forensic, root-cause focused. What broke, why, and what is the minimal surgical fix?
- **Role:** Receives failed task output + full reviewer/tester feedback. Makes targeted fixes without introducing new issues. Can request helper agents (researcher, language reviewers, etc.) via orchestrator.
- **Key behavior:** Does not build new things — only fixes specific failures. Severity-relative attempt limits: Critical=5, Standard=3, Polish=2. Counter never resets on the same task regardless of new issues introduced. After max attempts: task parked with full attempt history. Multiple instances run simultaneously for parallel failed tasks.
- **Owns files:** Same files as the original failed task (inherits ownership temporarily).

---

### mini-architect

- **Model:** Sonnet
- **Tools:** Read, Write, Glob, Grep
- **Cognitive Mode:** Architectural judgment thinking — what is the minimal decision needed to unblock this build without changing fundamentals?
- **Role:** Handles blockers that prevent the builder from running. Decomposes L tasks into M/S sub-tasks. Resolves ambiguities within existing architecture. Resolves merge conflicts. Decomposes integration test failures into fix tasks.
- **Key behavior:** Can request helper agents (researcher, domain builders to validate feasibility). All decisions logged to `artifacts/builder/mini-architect-log.md` (append-only). Multiple instances run simultaneously for parallel blockers.

**What it CAN do:**
- Decompose blocked tasks into smaller sub-tasks
- Resolve task spec ambiguity by choosing the most reasonable interpretation
- Choose between equally valid implementation approaches within existing ADRs
- Add small missed utilities the task graph assumed would exist

**What it CANNOT do:**
- Change any ADR
- Add features outside Prototyper/Architect scope
- Switch libraries or frameworks
- Make any decision that changes the product shape or end goal

- **Owns files:** `artifacts/builder/mini-architect-log.md` (append-only).

---

### screenshot-analyzer

- **Model:** Opus (needs strong visual reasoning)
- **Tools:** Read (images), Write
- **Cognitive Mode:** Visual diagnosis — what is visually wrong here?
- **Role:** Fix mode only. Analyses screenshot feedback from user, extracts structured description of visual issues (what element, what's wrong, severity).
- **Key behavior:** Output feeds triage routing in fix mode. Does not fix issues itself — produces structured diagnosis that bug-fixer or builder-ui can act on.

---

## Q&A Decisions (2026-03-22)

### Worker Isolation
- Claude Code built-in `isolation: "worktree"` per worker task — automatic creation and cleanup
- File ownership pre-flight: orchestrator verifies no two parallel tasks share files before dispatching
- No GitHub involvement during build — PRs left to Launcher
- After task passes all gates: worktree merged to phase branch, cleaned up

### Concurrency
- Orchestrator dispatches all ready tasks as parallel Agent tool calls in a single response
- Up to 20+ simultaneous agents — no artificial cap
- **Any agent type can have multiple instances running simultaneously** — ten `builder-composer` instances, five `bug-fixer` instances, etc.
- Each instance assigned non-overlapping file set by orchestrator before dispatch
- Only hard constraint: file ownership (no two concurrent instances own the same file)

### Review Pipeline
- **Per task:** convention-checker (first) → reviewer-code
- **Phase boundary:** reviewer-security + reviewer-design (parallel)
- Convention-checker runs before reviewer-code so code reviewer works on convention-clean output — fewer mixed-concern failures
- Conditional reviewers (accessibility, performance, api-design, typescript, python) run at phase boundary when active for project

### Testing
- Unit tests: bundled with tasks (Phase 3 decision), tester-unit runs per task after reviewer-code passes
- Integration tests: phase gates — tester-integration runs at phase boundary, must pass before next phase activates
- E2E tests: milestone boundaries only (MVP, V1, V2) — requires full stack wired together

### Bug-Fix Cycle
- Severity-relative attempt limits: Critical=5, Standard=3, Polish=2
- Counter never resets on same task regardless of new issues introduced during fixing
- After max attempts: task parked with full attempt history
- bug-fixer has own cognitive mode (diagnostic thinking) — can request helper agents

### Autonomous Operation
- No time-of-day assumptions — Builder runs autonomously for as long as needed
- On any exit condition: writes run-report.md + build-index.md
- Notification hook stubbed as TODO — wire in Telegram/push when ready
- Stall detection: no worker output for 10 min → kill and requeue

### Git Workflow
- Per task: temporary worktree branch (auto via isolation: "worktree", cleaned after merge)
- Per phase: persistent phase branch — `max-agents/phase-N`
- Main: untouched during build — Launcher creates PRs
- Commit format: `[task-id] task title`

### Builder Agent Taxonomy
Cognitive-based, not domain-based. Cognitive mode determines the mental model brought to the task; domain context comes from the task spec.

**Core builders (always, parallel):** builder-composer (orchestration), builder-systems (design), builder-data (relational), builder-integration (defensive), builder-ui (visual), builder-infra (operational)

**Conditional builders:** builder-ml, builder-realtime, builder-mobile, builder-api

**Core reviewers:** reviewer-code (per task), reviewer-security (phase boundary), reviewer-design (phase boundary)

**Conditional reviewers:** reviewer-accessibility, reviewer-performance, reviewer-api-design, reviewer-typescript, reviewer-python *(extensible: reviewer-swift, reviewer-go, etc.)*

**Core testers:** tester-unit (per task), tester-integration (phase gates), tester-e2e (milestones)

**Conditional testers:** tester-visual, tester-performance, tester-accessibility, tester-contract

**Support:** bug-fixer (diagnostic thinking), mini-architect (architectural judgment thinking), convention-checker (Haiku, compliance), screenshot-analyzer (Opus, fix mode visual analysis)

### Task Assignment Model
- `assigned_to: "builder-data"` — Architect assigns clear cognitive fit
- `assigned_to: "auto"` — ambiguous, Builder orchestrator decides at runtime, logs choice
- `requires: ["realtime"]` — flags conditional builder needed
- `may_need: ["researcher", "reviewer-typescript"]` — Architect's hint for likely support agents
- **One owner, unlimited support** — assigned builder owns task + files; can request any helper agent via orchestrator mid-execution

### L Task Splitting
- L tasks (5 files, complex) never dispatched directly to builder
- Routed through mini-architect first: decomposes into M/S sub-tasks with file ownership
- Sub-tasks logged and added to task-graph.json, then dispatched normally

### Scope and Milestones
- [SCOPE+] tasks resolved at Phase 3 task graph review — Builder never encounters them
- User selects target milestone at startup (MVP / V1 / V2 / all)
- Builder runs to that milestone boundary and stops

### Mini-Architect
- Renamed from mini-planner — operates across planning and design concerns
- Cognitive mode: architectural judgment thinking
- All decisions logged to mini-architect-log.md (append-only)
- Can unblock builds; cannot change fundamentals or scope-creep

### Fix Mode
- Two input methods: terminal natural language + file drops to feedback/inbox/
- Triage: bug/polish → bug-fixer; ux-issue → park (needs Prototyper); missing-feature → park (needs Architect)
- Fix tasks added to existing task graph, same pipeline as build mode
- Pre-decided during Prototyper/Researcher build session

### Phase 3 Alignment
- Worker names (`builder-composer`, `builder-systems`, etc.) are the canonical `assigned_to` values in task-graph.json — Phase 3 uses these names
- Phase 3 task-graph.json gains `requires` and `may_need` fields
- convention-checker defined in Phase 3 operates within Phase 4's per-task pipeline
