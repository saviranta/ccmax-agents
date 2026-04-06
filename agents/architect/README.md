# Architect Agent

The Architect converts a product definition into a complete technical blueprint. It reads the Prototyper's output and produces everything the Builder needs to start work: technology decisions, data models, API contracts, a security plan, and a parallel task graph with per-task specifications.

---

## What It Does

- Selects the technology stack (with your approval)
- Designs the data model and writes the database schema
- Defines API contracts for every endpoint
- Writes Architecture Decision Records (ADRs) for significant choices
- Designs the design system and component library structure
- Produces a security plan
- Generates `task-graph.json` — the complete parallel task graph with owned-file assignments
- Writes per-task spec documents for every task in the graph

---

## Input

The Architect reads `.max-agents/handoffs/prototyper-to-architect.json` automatically when it starts. You do not need to pass anything manually. If the handoff file is missing or malformed, it will tell you.

---

## Three Pause Gates

The Architect stops at three points and waits for your explicit approval before continuing. Do not rush through these.

### Gate 1: Stack Approval

The Architect proposes a technology stack based on the user stories, design constraints, and any relevant research. You review and approve, adjust, or veto.

This is where to surface your constraints:
- Hosting preferences or restrictions (Vercel, AWS, self-hosted)
- Budget limits that rule out paid services
- Team skill set (avoid tools your team doesn't know if the timeline is tight)
- Existing infrastructure you must integrate with

Once approved, the stack is locked and becomes the foundation for all subsequent decisions.

### Gate 2: Architecture Review

The Architect presents the ADRs, data model, API contracts, and security plan. You review for correctness and completeness.

Check for:
- Data model decisions that will be painful to migrate later
- API shapes that don't match what the Prototyper described
- ADR alternatives that were rejected without adequate justification
- Security decisions that don't match your requirements (auth strategy, data residency, etc.)

### Gate 3: Task Graph Review

The Architect presents `task-graph.json` and the per-task specs. This is the most important gate.

Check for:
- **File ownership conflicts** between tasks in the same phase — no two parallel tasks may claim the same file. Scan `owns_files` across tasks in each phase.
- Tasks that are L-sized (the mini-architect will split them, but flag any that seem mis-sized)
- Dependencies that look circular or unnecessary
- Tasks assigned to the wrong builder type

Once you approve this gate, the handoff to the Builder is written and the build phase can begin.

---

## Sub-Agents

The Architect uses 16 specialized sub-agents in parallel to cover different architecture domains:

- Data model designer
- API contract writer
- Auth and security planner
- Frontend architecture designer
- Design system specifier
- Integration mapper
- Performance and caching planner
- Error handling and observability designer
- Testing strategy planner
- Deployment and infrastructure planner
- Task graph generator
- Per-task spec writer (runs once per task)
- Mini-architect (splits L-sized tasks into S/M tasks)
- ADR writer
- Dependency resolver
- File ownership validator

You interact only with the orchestrating Architect — the sub-agents run silently.

---

## Output

All Architect output goes to `.max-agents/artifacts/architect/`:

```
.max-agents/artifacts/architect/
  adrs/
    ADR-001-[slug].md
    ADR-002-[slug].md
    ...
  data-model.sql              — full schema with indexes and constraints
  api-contracts.json          — all endpoints, request/response types
  design-system.md            — component library, token system, naming conventions
  security-plan.md            — auth strategy, data access rules, RLS policies
  task-graph.json             — the complete parallel task graph
  tasks/
    task-001-[slug].md
    task-002-[slug].md
    ...
```

The Builder reads `task-graph.json` to start. The per-task specs in `tasks/` are read by the individual builder sub-agents assigned to each task.

---

## How to Invoke

From your project directory, launch the Architect agent:

```bash
bash <agents-max>/scripts/run-agent.sh architect
```

Or directly:

```bash
claude --append-system-prompt "$(cat <agents-max>/agents/architect/CLAUDE.md)" --model opus
```

Then say something like "Start architecture phase."

The Architect will confirm it has found the Prototyper handoff, then proceed to the stack proposal.

---

## Tips

**Be specific at the stack approval gate.** The Architect's default recommendations are reasonable for a general case, but your constraints may make different choices better. If you have a hosting budget of $0/month, say so. If your team knows Go but not TypeScript, say so.

**Check owns_files at the task graph review.** File ownership conflicts between parallel tasks are the most common source of build problems. At the task graph review gate, scan the `owns_files` arrays for any file path that appears in more than one task within the same phase. The Architect's file ownership validator should catch these, but a manual check is worthwhile.

**ADRs are not just documentation.** The `Builder Constraints` section of each ADR is enforced during the build phase. If an ADR says "MUST NOT store tokens in localStorage," every builder-ui sub-agent will be instructed accordingly. Errors in ADR constraints propagate to every task that touches the relevant area.

**L-sized tasks are expected.** The mini-architect will split them. You do not need to resize them manually at the task graph review. Focus your review on correctness of dependencies and file ownership rather than trying to resize every task.

---

## Self-Improvement Integration

The Architect records issues it encounters during a session using `improvement.sh`:

```bash
bash <toolkit_root>/scripts/improvement.sh record <project_root> <severity> <category> "<description>"
```

- **severity**: `critical` or `non-critical`
- **category**: `workflow`, `agent`, `handoff`, or `task-spec`

**When to record:**
- A Prototyper handoff is structurally incomplete in a way that caused rework → `handoff`
- A sub-agent produced unusable output requiring orchestrator intervention → `agent`
- A pause gate decision was not captured in the handoff → `workflow`
- A task-spec pattern caused downstream builder failures → `task-spec`

Issues are written to `.max-agents/artifacts/improvement-journal.md`. Critical issues block milestone progression until resolved via `improvement.sh apply`.
