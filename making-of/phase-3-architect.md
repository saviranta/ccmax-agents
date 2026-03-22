# Phase 3: Architect

**Status:** Q&A complete — ready for implementation

## Overview

The Architect agent takes Prototyper artifacts (vision document, wireframes, user stories, flows, design constraints) and produces a complete technical blueprint with a parallelizable task graph for the Builder. It bridges the gap between human-validated product intent and autonomous code generation. It runs in Terminal 2 as the second major pipeline stage, consuming Prototyper output and producing Builder input.

## Prototyper Inputs

All Phase 2 artifacts live at `artifacts/prototyper/`. The Architect reads these at startup via the handoff document at `handoffs/prototyper-to-architect.json` (Phase 0 handoff protocol), which lists every artifact produced.

### Artifact Map

| Prototyper artifact | Path | Read by |
|---------------------|------|---------|
| Vision + goals + target users | `artifacts/prototyper/vision.md` | context-analyzer, all domain agents |
| Design constraints (must-haves, brand, accessibility, platforms) | `artifacts/prototyper/design-constraints.md` | context-analyzer, all domain agents |
| Wireframes (screen layouts, HTML mockups) | `artifacts/prototyper/wireframes/screen-*.md` | context-analyzer, ux-designer, frontend-architect |
| User stories (with tradeoffs, happy/unhappy paths, usage context) | `artifacts/prototyper/user-stories/us-*.md` | context-analyzer, ux-designer, data-architect, backend-architect, security-architect |
| User flows (journey maps, state transitions, edge cases) | `artifacts/prototyper/flows/flow-*.md` | context-analyzer, data-architect, backend-architect, security-architect |
| Reference screenshots | `artifacts/prototyper/references/ref-*.png` | ux-designer |
| Reference analyses (extracted patterns, components, color schemes) | `artifacts/prototyper/references/ref-*-analysis.md` | ux-designer, frontend-architect |
| Draft design system (rough tokens, component patterns) | `artifacts/prototyper/design-constraints.md` (design section) | ux-designer |
| Handoff document (artifact list, decisions made, open questions) | `handoffs/prototyper-to-architect.json` | orchestrator (first read, validates completeness) |

### What Each Agent Reads from Phase 2

- **context-analyzer** — `vision.md`, `design-constraints.md`, all `user-stories/`, all `flows/`, all `wireframes/`, `handoffs/prototyper-to-architect.json`
- **ux-designer** — `wireframes/`, `user-stories/`, `references/` (images + analyses), design system section of `design-constraints.md`
- **data-architect** — `user-stories/`, `flows/`, `design-constraints.md`
- **backend-architect** — `user-stories/`, `flows/`, `design-constraints.md`, `vision.md`
- **frontend-architect** — `wireframes/`, `user-stories/`, `references/ref-*-analysis.md`, `design-constraints.md`
- **security-architect** — `user-stories/`, `flows/`, `design-constraints.md`, `vision.md`
- **task-decomposer** — `vision.md`, `design-constraints.md` (for scope boundary — anything not in these is a `[SCOPE+]` candidate)

### Handoff Validation

Before dispatching any sub-agents, the orchestrator checks `handoffs/prototyper-to-architect.json` for completeness. If any of the following are missing, it pauses and alerts the user:

- `vision.md` — cannot proceed without it
- At least one user story — cannot proceed without it
- At least one flow — warns but can proceed
- `design-constraints.md` — warns but can proceed

---

## Why Phase 3

The Architect is the critical bridge between human intent and autonomous execution. The quality of its output — clear ADRs, unambiguous contracts, a task graph with explicit file ownership — determines whether the Builder can run autonomously without getting stuck. A weak architecture phase produces a Builder that constantly blocks on ambiguity, asks redundant questions, or makes contradictory decisions across files. A strong architecture phase produces a Builder that executes deterministically.

## Architecture

```
ARCHITECT (Terminal 2) — Opus orchestrator
├── context-analyzer
├── [domain agents — parallel]
│   ├── ux-designer
│   ├── frontend-architect
│   ├── backend-architect
│   ├── data-architect
│   └── security-architect
├── integration-architect
├── [pipeline — sequential]
│   ├── task-decomposer
│   ├── estimator
│   └── convention-checker
└── [conditional specialists — dispatched when needed]
    ├── researcher
    ├── data-scientist
    ├── mobile-architect
    ├── realtime-architect
    ├── infra-architect
    └── api-architect
```

**Context Phase:**
- `context-analyzer` (Sonnet) — reads codebase and Prototyper artifacts, produces structured context summary

**Core Domain (always run, parallel):**
- `ux-designer` (Sonnet) — design system, component hierarchy, interaction patterns
- `frontend-architect` (Sonnet) — component tree, state management, routing, build config
- `backend-architect` (Sonnet) — service boundaries, API design, business logic structure
- `data-architect` (Sonnet) — schema design, migrations, data flow, caching strategy
- `security-architect` (Sonnet) — auth model, threat surface, input validation, secrets management

**Integration (runs after domain agents complete):**
- `integration-architect` (Opus) — verifies seams between domains, resolves ADR conflicts, produces integration contracts and API validation rules

**Pipeline (sequential after integration):**
- `task-decomposer` (Opus) — breaks architecture into task graph with unique file ownership per task
- `estimator` (Haiku) — sizes tasks, flags risks, proposes milestones
- `convention-checker` (Haiku) — validates naming, structure, and style conventions across all artifacts

**Conditional Specialists (dispatched by orchestrator based on project needs):**
- `researcher` (Sonnet) — investigates unknowns via WebSearch, documents findings in ADRs
- `data-scientist` (Sonnet) — ML pipeline design, model selection, data preprocessing strategy
- `mobile-architect` (Sonnet) — native/hybrid decisions, platform-specific patterns, offline-first design
- `realtime-architect` (Sonnet) — WebSocket/SSE design, presence, conflict resolution, sync protocols
- `infra-architect` (Sonnet) — deployment topology, CI/CD, containerization, scaling strategy
- `api-architect` (Sonnet) — external API integrations, rate limiting, SDK design, versioning

### Execution Model

Semi-autonomous — works independently but pauses at three explicit decision points.

#### Concurrency Model

The orchestrator can spawn up to **20+ simultaneous sub-agents**. There is no artificial cap at 4. The only constraints are:

- **File ownership** — no two concurrent agents may own the same output file
- **Dependency order** — agents that consume another agent's output must wait for it to complete

The orchestrator may also spawn **multiple instances of the same agent type** when the work can be partitioned. For example, if the data model is large, two `data-architect` instances can each own a distinct set of output files. If there are many components, two `ux-designer` instances can split the component set. The orchestrator decides the partition and assigns file ownership before dispatching.

**Phase 1: Context Gathering**

1. `context-analyzer` reads existing codebase (if any) and all Prototyper artifacts (vision, wireframes, user stories, flows, design constraints). Produces structured summary for orchestrator: tech detected, constraints identified, open questions.
2. Orchestrator identifies stack decisions needed — framework, language, database, hosting, key libraries.
3. Orchestrator conducts lifecycle interview with user: deployment context (local tool vs. published product vs. internal service), maintenance model (solo dev, team, open source), how close the current prototype is to the end scope of the product.
4. Orchestrator presents concrete stack and architecture recommendation. For genuine tradeoffs only (where multiple options have real merit), presents options with trade-off analysis to user.
5. **Decision pause** — user approves stack and architecture direction before sub-agents dispatch.

**Phase 2: Architecture Design (parallel)**

6. Orchestrator dispatches core domain agents in parallel (`ux-designer`, `frontend-architect`, `backend-architect`, `data-architect`, `security-architect`). Each agent owns distinct output files — no file conflicts between parallel agents.
7. Conditional specialists dispatched in parallel alongside domain agents if project needs them (e.g., `realtime-architect` for chat features, `mobile-architect` for native targets).
8. Domain agents produce their artifacts independently: ADRs, schema definitions, component trees, security models, design tokens.
9. `integration-architect` runs after all domain agents complete. Verifies seams between domains, resolves ADR conflicts, produces final integration contracts and API validation rules.
10. **Architecture pause** — orchestrator synthesizes outputs, presents key ADRs and design system to user for approval.

**Phase 3: Task Graph**

11. `task-decomposer` breaks approved architecture into task graph. Enforces unique file ownership per task (enables parallel Builder execution). Defines explicit phase gates between build phases.
12. `estimator` sizes tasks (S/M/L), flags risk areas, proposes MVP/V1/V2 milestones.
13. **Task graph pause** — user reviews tasks, milestones, and scope before Builder starts.
14. `convention-checker` validates all artifacts, then orchestrator generates handoff document for Builder.

### Uncertainty Handling

- **Minor unknowns** — `researcher` sub-agent handles internally via WebSearch, documents result in the relevant ADR. No human involvement.
- **Human pause triggered only for:**
  - Irreversible or expensive decisions (database choice, hosting provider lock-in)
  - Product/business tradeoffs where no technical winner exists (feature scope, UX direction)
  - Security implications requiring user judgment (auth model, data residency, third-party trust)

### Scope Control

- **Scope expansion < 30% of implementation** — flagged in task graph with clear `[SCOPE+]` marking. User decides at task graph review whether to include, defer, or drop.
- **Scope expansion > 30% of implementation** — hard stop. Orchestrator surfaces the scope issue to user before proceeding. Architecture work pauses until user provides direction.

## Human-in-the-Loop

| Step | Human Action | Agent Action |
|------|-------------|--------------|
| 1. Start | Confirm Prototyper handoff received | `context-analyzer` reads artifacts, produces structured summary |
| 2. Stack approval | Review recommendation, approve or redirect | Present stack suggestion with options for genuine tradeoffs only |
| 3. Architecture | Review ADRs + design system, approve or redirect | Present domain ADR outputs + integration contracts |
| 4. Task graph | Review tasks, milestones, adjust scope/priorities | Present task graph with estimates and MVP/V1/V2 milestones |
| 5. Handoff | Confirm ready for Builder | Generate handoff document |

Three explicit pause points after context gathering: stack/architecture decisions, architecture review, and task graph approval. The user never waits on agent work — pauses occur only when agent work completes and a decision is needed.

---

## Output Format

### Directory Structure

```
artifacts/architect/
├── architecture/
│   ├── context-summary.md       # context-analyzer output: detected stack, constraints, open questions
│   ├── overview.md              # Tier 1: system topology, integration contracts, non-negotiables (everyone reads)
│   ├── adr/                     # Tier 2: domain-scoped ADRs (read by relevant agents only)
│   │   ├── ADR-backend-001.md
│   │   ├── ADR-frontend-001.md
│   │   ├── ADR-data-001.md
│   │   ├── ADR-security-001.md
│   │   ├── ADR-integration-001.md
│   │   └── [conditional: ADR-ml-*, ADR-mobile-*, ADR-realtime-*, ADR-infra-*, ADR-api-*]
│   ├── data-model.md            # Entity definitions, relationships, indexes, migration strategy (markdown)
│   ├── api-contracts.json       # OpenAPI JSON spec
│   ├── component-tree.md        # Frontend component hierarchy
│   └── infrastructure.md        # Hosting, CI/CD, env config
├── design-system.md             # Tokens, components, patterns, responsive breakpoints (markdown)
├── storybook/                   # Storybook story stubs per component
│   ├── UserProfile.stories.ts
│   └── ...
├── security-plan.md             # Full STRIDE threat model, mitigations mapped to tasks
├── conventions.md               # Coding conventions, naming, file structure, error handling, commit format
├── research/                    # One file per investigation (researcher sub-agent)
├── task-graph.json              # The build manifest
├── task-specs/                  # Hyper-detailed spec per task
│   ├── task-001.md
│   ├── task-002.md
│   └── ...
└── estimates.md                 # Scope estimate, risk areas, MVP/V1/V2 milestone cuts
```

### ADR Structure (Two-Tier)

The architecture decision record system uses two tiers to separate universal constraints from domain-specific decisions.

- **Tier 1 — architecture/overview.md**: System topology, integration contracts between domains, non-negotiable constraints (performance targets, platform requirements). Every agent reads this. Written by `integration-architect` after domain agents complete.
- **Tier 2 — architecture/adr/**: Domain-scoped ADRs. Each agent reads only the ADRs for its domain. Written by domain agents.

ADR format:

```markdown
## ADR — [Domain: Decision Name]
Date: ISO date
Status: proposed | accepted | superseded

### Context
What situation requires this decision

### Decision
What was decided

### Rationale
Why this over alternatives

### Alternatives Considered
| Option | Reason rejected |
|--------|----------------|

### Consequences
What becomes easier, harder, or different as a result

### Constraints on Builders
What builders must not do as a result of this decision
```

### conventions.md Structure

```markdown
# Project Conventions

## Naming
- Files: kebab-case
- Components: PascalCase
- Functions/variables: camelCase
- Constants: SCREAMING_SNAKE_CASE
- Database tables: snake_case

## File Structure
[project-specific]

## Code Style
[language-specific rules]

## Error Handling
[patterns]

## Testing
[conventions]

## Commit Format
[format]

## API Conventions
[REST/naming/response shape rules]
```

Note: This file is enforced by the `convention-checker` sub-agent as a gate after every Builder task — it is NOT injected into task prompts.

### Task Spec Format (Hyper-Detailed)

```markdown
# Task 003: Create UserProfile component

## Assignment
builder-ui

## Phase
phase-1

## Milestone
MVP

## Size
M

## Dependencies
- task-001 (project scaffold — must exist: src/app/layout.tsx)
- task-002 (design system setup — must exist: src/styles/tokens.css)

## Files to Create (this task owns these — no other parallel task may touch them)
- src/components/UserProfile.tsx
- src/components/UserProfile.test.tsx

## Files to Read (with relevant sections)
- src/types/user.ts (lines 1-30: User interface definition)
- src/styles/tokens.css (lines 1-50: color and spacing tokens)
- artifacts/architect/design-system.md (UserProfile component spec)
- artifacts/architect/conventions.md (all sections)

## Specification

### Component Props
\`\`\`typescript
interface UserProfileProps {
  user: User;
  onEdit?: () => void;
  variant: 'compact' | 'full';
}
\`\`\`

### Behavior
- `compact` variant: avatar + name only, 48px height
- `full` variant: avatar + name + email + edit button, 120px height
- Avatar falls back to initials if imageUrl is null
- Edit button only visible if onEdit is provided

### Test Requirements (unit tests — bundled with this task)
- Renders compact variant with correct dimensions
- Renders full variant with all fields
- Edit button visibility controlled by onEdit prop
- Avatar fallback to initials works

## Acceptance Criteria
- [ ] Component renders without errors
- [ ] Both variants match design system specs
- [ ] All tests pass
- [ ] TypeScript compiles with no errors
- [ ] All conventions in conventions.md followed
```

### task-graph.json Format

```json
{
  "version": "1.0",
  "project": "my-app",
  "generated_by": "architect",
  "generated_at": "2026-03-22T16:00:00Z",
  "milestones": {
    "mvp": { "description": "Core functionality, locally runnable", "phases": ["phase-1", "phase-2"] },
    "v1": { "description": "Production-ready, deployed", "phases": ["phase-3"] },
    "v2": { "description": "Full feature set", "phases": ["phase-4"] }
  },
  "phases": [
    {
      "id": "phase-1",
      "name": "Project Setup & Foundation",
      "milestone": "mvp",
      "tasks": ["task-001", "task-002", "task-003"],
      "integration_test_tasks": ["task-010"],
      "gate": "all phase-1 tasks done + task-010 passed before phase-2 activates"
    }
  ],
  "tasks": {
    "task-001": {
      "title": "Initialize Next.js project with TypeScript",
      "assigned_to": "builder-infra",
      "size": "S",
      "milestone": "mvp",
      "depends_on": [],
      "owns_files": ["package.json", "tsconfig.json", "src/app/layout.tsx"],
      "requires": [],
      "may_need": [],
      "spec_file": "task-specs/task-001.md",
      "status": "pending",
      "phase": "phase-1",
      "type": "implementation"
    },
    "task-005": {
      "title": "Wire authentication flow into dashboard layout",
      "assigned_to": "auto",
      "size": "M",
      "milestone": "mvp",
      "depends_on": ["task-001", "task-003", "task-004"],
      "owns_files": ["src/app/dashboard/layout.tsx", "src/middleware.ts"],
      "requires": [],
      "may_need": ["reviewer-typescript"],
      "spec_file": "task-specs/task-005.md",
      "status": "pending",
      "phase": "phase-1",
      "type": "implementation"
    },
    "task-010": {
      "title": "Integration test: phase-1 scaffold works end to end",
      "assigned_to": "builder-composer",
      "size": "S",
      "milestone": "mvp",
      "depends_on": ["task-001", "task-002", "task-003"],
      "owns_files": ["tests/integration/phase-1.test.ts"],
      "requires": [],
      "may_need": [],
      "spec_file": "task-specs/task-010.md",
      "status": "pending",
      "phase": "phase-1",
      "type": "integration-test"
    }
  }
}
```

---

## Agent Definitions

### Architect (Orchestrator)

- **Model:** Opus
- **Tools:** All
- **Role:** Reads the context-analyzer summary and all Prototyper artifacts. Conducts the lifecycle interview with the user. Presents a stack recommendation. Dispatches domain agents in parallel. Synthesizes their outputs via the integration-architect. Surfaces decision points to the user. Oversees task graph production.
- **Key behavior:** Thinks "what does the Builder need to know to build this without asking?" Every gap in the architecture docs is a potential overnight build failure. Dispatches conditional specialists only when project characteristics require them.

---

### Sub-Agent: context-analyzer

- **Model:** Sonnet
- **Tools:** Read, Glob, Write
- **Role:** Reads `handoffs/prototyper-to-architect.json` first to confirm all expected artifacts are present. Then reads: `artifacts/prototyper/vision.md`, `artifacts/prototyper/design-constraints.md`, all files in `artifacts/prototyper/user-stories/`, `artifacts/prototyper/flows/`, and `artifacts/prototyper/wireframes/`. If an existing codebase is present, reads its structure and key files. Extracts: current stack (if any), existing conventions, architectural constraints implied by the design, UX tradeoffs documented by the Prototyper that affect architecture (e.g. "needs real-time", "must work offline"). Produces a structured summary for the orchestrator.
- **Key behavior:** Runs first, before any other sub-agent. Validates handoff completeness and alerts orchestrator if required artifacts are missing. Its output is the orchestrator's foundation for the lifecycle interview and stack recommendation.
- **Owns files:** `architecture/context-summary.md`

---

### Sub-Agent: ux-designer

- **Model:** Sonnet
- **Tools:** Read, Write
- **Role:** Takes wireframes and user stories and produces detailed component specifications, interaction patterns (hover, focus, loading, error, empty states), responsive breakpoints, animation specs, and Storybook story stubs.
- **Owns files:** `design-system.md`, `storybook/`

---

### Sub-Agent: data-architect

- **Model:** Sonnet
- **Tools:** Read, Write
- **Role:** Designs the data model from user stories and flows. Produces: entity definitions, relationships, indexes, migration strategy, seed data requirements, and query patterns for common operations. Documents the schema in markdown (not actual schema files). Produces an OpenAPI JSON spec for all endpoints.
- **Owns files:** `architecture/data-model.md`, `architecture/api-contracts.json`

---

### Sub-Agent: backend-architect

- **Model:** Sonnet
- **Tools:** Read, Write
- **Role:** Designs the backend from user stories and the data model. Produces: service boundaries, auth strategy, caching strategy, error handling patterns, background job requirements, and infrastructure requirements.
- **Owns files:** `architecture/adr/ADR-backend-*.md`, `architecture/infrastructure.md`

---

### Sub-Agent: frontend-architect

- **Model:** Sonnet
- **Tools:** Read, Write
- **Role:** Designs the frontend from wireframes, component specs, and API contracts. Produces: component tree, state management approach, routing structure, data fetching patterns, and build configuration.
- **Owns files:** `architecture/component-tree.md`, `architecture/adr/ADR-frontend-*.md`

---

### Sub-Agent: security-architect

- **Model:** Sonnet
- **Tools:** Read, Write
- **Role:** Conducts a full STRIDE threat model from the architecture docs. Produces: threat inventory, auth flow details, input validation rules, rate limiting requirements, secret management approach, and CORS/CSP configuration. Maps each mitigation to specific tasks.
- **Owns files:** `security-plan.md`

---

### Sub-Agent: integration-architect

- **Model:** Opus
- **Tools:** Read, Write
- **Role:** Runs after all domain agents complete. Reads all domain ADRs and artifacts, verifies contracts between domains are consistent (e.g., frontend API calls match backend endpoints), resolves conflicts, and produces final integration contracts and cross-domain API validation rules.
- **Key behavior:** The seam-owner. If the frontend-architect assumed a REST endpoint that the data-architect did not define, the integration-architect catches and resolves it. Any unresolvable conflict escalates to the orchestrator for a human decision.
- **Owns files:** `architecture/overview.md`, `architecture/adr/ADR-integration-*.md`

---

### Sub-Agent: task-decomposer

- **Model:** Opus (requires strong reasoning for dependency analysis)
- **Tools:** Read, Write
- **Role:** Takes all architecture docs and produces the task graph.
- **Critical rules:**
  - Each task touches 1-5 files maximum.
  - Tasks sized S/M/L as a proxy for context window load.
  - No two tasks that run in parallel may touch the same file — unique file ownership is the parallelism contract.
  - Dependencies must be explicit (no implicit ordering).
  - Every file that needs to exist must be created by a preceding task.
  - Phase gates: all implementation tasks in a phase must complete before integration test tasks for that phase begin; integration tests must pass before next phase tasks activate.
  - Task specs must include exact file paths, function signatures, and test expectations.
  - Unit tests and code quality/convention/contract review are bundled into implementation tasks.
  - Integration and end-to-end tests are separate tasks.
  - Scope expansion > 30% of what the Prototyper defined triggers a hard stop flagged to the orchestrator.
  - Scope expansion < 30% is marked clearly `[SCOPE+]` in the task graph for user decision at review.
  - Milestones: tasks grouped into MVP / V1 / V2 as shippable increments.
- **Owns files:** `task-graph.json`, `task-specs/`

---

### Sub-Agent: estimator

- **Model:** Haiku
- **Tools:** Read, Write
- **Role:** Reads the task graph, sizes each task (S/M/L), estimates total scope, identifies risk areas (tasks likely to need multiple fix cycles), and validates that MVP/V1/V2 milestone cuts are actually shippable increments.
- **Owns files:** `estimates.md`

---

### Sub-Agent: convention-checker

- **Model:** Haiku
- **Tools:** Read, Write
- **Role:** Dual-phase agent. In the Architect phase: validates all produced artifacts (task specs, ADRs, conventions.md itself) for structural consistency before handoff to Builder. In the Builder phase (Phase 4): runs after each Builder task completes as a per-task quality gate — reads `conventions.md` and the task output, verifies compliance, flags violations back to the bug-fixer before the code reviewer sees the output.
- **Key behavior:** Compliance is enforced as a gate, not via injecting conventions into every task prompt (which would bloat input tokens). The same agent definition is reused in both phases — the Architect produces `conventions.md`, the Builder enforces it.
- **Owns files:** None (reads `conventions.md`, writes violation reports inline to task status)

---

### Sub-Agent: researcher (conditional)

- **Model:** Sonnet
- **Tools:** Read, Write, WebSearch, WebFetch
- **Role:** Handles unknowns during the architecture phase. Triggered when the orchestrator or domain agents hit questions answerable by external research. Returns findings for the requesting agent to document in an ADR.
- **Triggered for:** library evaluation, external API investigation, technology selection, security advisories for dependencies.
- **Not triggered for:** questions answerable from the existing codebase or Prototyper artifacts.
- **Owns files:** `research/` (one file per investigation)

---

### Sub-Agent: data-scientist (conditional)

- **Model:** Sonnet
- **Tools:** Read, Write
- **Role:** Dispatched when the project includes ML or data science components. Produces: ML pipeline architecture, model serving strategy, training infrastructure requirements, and data pipeline design.
- **Owns files:** `architecture/adr/ADR-ml-*.md`

---

### Sub-Agent: mobile-architect (conditional)

- **Model:** Sonnet
- **Tools:** Read, Write
- **Role:** Dispatched when the project includes mobile (native or hybrid). Produces: mobile architecture decisions, offline strategy, push notification architecture, app store requirements, and native capability requirements.
- **Owns files:** `architecture/adr/ADR-mobile-*.md`

---

### Sub-Agent: realtime-architect (conditional)

- **Model:** Sonnet
- **Tools:** Read, Write
- **Role:** Dispatched when the project requires real-time features (WebSockets, event-driven systems, pub/sub). Produces: real-time architecture decisions, connection management, event schema, and scaling approach.
- **Owns files:** `architecture/adr/ADR-realtime-*.md`

---

### Sub-Agent: infra-architect (conditional)

- **Model:** Sonnet
- **Tools:** Read, Write
- **Role:** Dispatched for complex infrastructure requirements (multi-region, Kubernetes, IaC). Produces: infrastructure architecture, deployment topology, IaC approach, and scaling strategy.
- **Owns files:** `architecture/adr/ADR-infra-*.md`

---

### Sub-Agent: api-architect (conditional)

- **Model:** Sonnet
- **Tools:** Read, Write
- **Role:** Dispatched when building a public-facing API product. Produces: API design principles, versioning strategy, developer experience requirements, rate limiting architecture, and API documentation approach.
- **Owns files:** `architecture/adr/ADR-api-*.md`

---

## Q&A Decisions (2026-03-22)

### Architecture Depth

#### ADR Structure

Two-tier architecture documentation:

- **Tier 1** (`architecture/overview.md`): System topology, integration contracts, non-negotiables. Read by every agent.
- **Tier 2** (`architecture/adr/`): Domain-scoped ADRs. Each ADR is read only by the agent responsible for that domain.

ADR count is not fixed — one ADR per domain that has genuine tradeoffs. Cross-cutting concerns (integration contracts, end-to-end vision) belong in the Tier 1 overview, not in domain ADRs.

#### Stack Decision Flow

1. `context-analyzer` derives already-decided stack elements from the existing codebase and Prototyper artifacts.
2. Orchestrator conducts a lifecycle interview covering: deployment context (local vs. published/maintained), maintenance model, and how close the current prototype is to end-product scope.
3. Orchestrator presents a concrete recommendation. Options are presented only where genuine tradeoffs exist.
4. Sub-agents are dispatched only after the user approves the stack direction.

#### Schema Artifacts

Data model is documented in markdown files (`.md`). Builder generates the actual schema files from these documents.

#### API Contracts

OpenAPI JSON spec format. Machine-readable; Builder can validate against it.

#### Security

Full STRIDE threat model is applied.

#### Conventions

- Documented in a dedicated `conventions.md` file.
- Enforced by `convention-checker` (Haiku) as a post-task verification gate — not injected into agent prompts.
- Rationale: injecting conventions into every prompt bloats input tokens. A post-task gate enforces compliance without that cost.

---

### Task Decomposition

#### Task Size

- Sizing: S / M / L, used as a token-cost proxy.
  - **S**: 1–2 files, straightforward work.
  - **M**: 3–4 files, moderate cross-referencing.
  - **L**: 5 files max, complex logic. `estimator` flags L tasks as risk.
- **Parallelism contract**: unique file ownership. No two tasks that run in parallel may touch the same file.

#### Tests

- **Unit tests + code quality / convention / contract review**: bundled into implementation tasks as part of acceptance criteria.
- **Integration and end-to-end tests**: separate tasks in the task graph.

#### Phase Gates

- All implementation tasks in a phase must complete before integration test tasks for that phase can start.
- Integration tests must pass before tasks in the next phase activate.

#### Uncertainty Handling

- Unknowns are handled internally: `researcher` sub-agent + WebSearch.
- A human pause is triggered only for:
  - Irreversible or expensive decisions.
  - Product or business tradeoffs.
  - No clear winner among options.
  - Security implications requiring user judgment.
- Prototyper gaps:
  - **Minor gap**: documented as an assumption in the relevant ADR.
  - **Significant gap** (missing core flow, ambiguous success criteria): pause and ask the user.

#### Scope Control

- Scope expansion **< 30%** of Prototyper-defined scope: flagged `[SCOPE+]` in the task graph; user decides at task graph review.
- Scope expansion **> 30%**: hard stop — surface to user before proceeding.

#### Milestones

- `task-decomposer` proposes MVP / V1 / V2 as shippable increments in the task graph.
- `estimator` validates that each milestone cut is actually shippable.

---

### Design System

- Tokens and component specs documented in `design-system.md` (markdown).
- Storybook story stubs included as part of component spec output; `ux-designer` owns these.

---

### Agent Interactions

#### Research

Handled internally by the `researcher` sub-agent via WebSearch. Does not require a human pause.

#### Back-Channel to Prototyper

Not possible — Prototyper runs in a separate terminal session. Protocol:

- **Minor gaps**: document as an assumption in the relevant ADR.
- **Significant gaps** (missing core flow, ambiguous success criteria): pause and ask the user.

---

### Agent Taxonomy

#### Core Domain Agents — always run, in parallel

`ux-designer`, `frontend-architect`, `backend-architect`, `data-architect`, `security-architect`

#### Integration Agent — always runs, after domain agents

`integration-architect` — owns the seams between domains, resolves ADR conflicts.

#### Pipeline Agents — always run

`context-analyzer` (runs first, before any domain agents), `task-decomposer`, `estimator`, `convention-checker`

#### Conditional Specialists — dispatched by Orchestrator based on project needs

`researcher`, `data-scientist`, `mobile-architect`, `realtime-architect`, `infra-architect`, `api-architect`

#### Design Principle

Domain agents run in parallel and own distinct output files. Parallelism is safe because file ownership is explicit and unique — no file conflicts. The `integration-architect` runs after all domain agents complete, owns the seams, and produces the Tier 1 overview that every subsequent agent reads.

#### Concurrency Rules

- Orchestrator may run up to **20+ simultaneous sub-agents** — no artificial cap.
- Orchestrator may spawn **multiple instances of the same agent type** when work can be partitioned (e.g., two `data-architect` instances splitting a large schema, two `ux-designer` instances splitting the component set).
- Orchestrator assigns file ownership before dispatching — each instance owns a distinct, non-overlapping set of output files.
- The only hard constraints are file ownership (no two concurrent agents own the same file) and dependency order (consumers wait for producers).
