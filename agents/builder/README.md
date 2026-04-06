# Builder Agent

The Builder is an autonomous code generation engine. It reads the Architect's task graph and dispatches specialized sub-agents in parallel to implement every task — writing, testing, and committing code — until a milestone is complete or it cannot continue without your intervention.

---

## What It Does

- Reads the task graph and determines which tasks are ready to run (all dependencies met)
- Dispatches specialized builder sub-agents in parallel, one per task
- Manages file ownership locks to prevent concurrent writes to the same file
- Commits completed tasks to phase branches in git
- Classifies and handles feedback you drop into the feedback inbox
- Tracks blocked and failed tasks and surfaces them in the run report
- Automatically splits L-sized tasks using the mini-architect before dispatching them

The Builder never writes code directly. It only orchestrates. All code is written by the specialized sub-agents it dispatches.

---

## Input

The Builder reads two files automatically when it starts:

- `.max-agents/handoffs/architect-to-builder.json` — pipeline metadata and configuration
- `.max-agents/artifacts/architect/task-graph.json` — the complete task graph

If either file is missing, the Builder will tell you. Do not manually edit these files.

---

## How to Invoke

From your project directory, launch the Builder agent:

```bash
bash <agents-max>/scripts/run-agent.sh builder
```

Or directly:

```bash
claude --append-system-prompt "$(cat <agents-max>/agents/builder/CLAUDE.md)" --model opus
```

Then state your target milestone, e.g. "Build to MVP" or "Build to V1."

Replace the milestone name with whichever stable state you want to reach. The Builder will run all phases required to reach that milestone.

---

## Milestones

Milestones represent stable, deployable states. Each milestone is a superset of the previous.

| Milestone | Meaning |
|-----------|---------|
| **MVP** | The minimum set of features that validates the core use case |
| **V1** | A complete, polished first version ready for real users |
| **V2** | Extended features and scale improvements |

Tasks in the task graph are tagged with a milestone. The Builder runs all tasks up to and including the requested milestone, in phase order.

---

## Builder Sub-Agents

The Builder maintains a pool of 20+ specialized sub-agents:

- `builder-ui` — React components, pages, client-side logic
- `builder-api` — API routes, server handlers, middleware
- `builder-data` — Database schemas, migrations, queries
- `builder-systems` — Auth, caching, queuing, platform config
- `builder-integration` — Third-party APIs, webhooks, external services
- `builder-ml` — Model inference, embeddings, AI pipelines
- `builder-mobile` — Native mobile
- `builder-realtime` — WebSockets, SSE, subscriptions
- `builder-infra` — CI/CD, Dockerfile, environment config
- `builder-composer` — Cross-cutting coordination tasks
- `debugger-quick` — Fast single-pass triage for unclear failures (Sonnet)
- `debugger-deep` — Hypothesis-driven multi-iteration debugging for hard bugs (Opus)

Each sub-agent receives its task spec, the relevant ADR constraints, and its owned-file list. It writes its files, runs the tests specified in the task, and reports back.

---

## Fix Mode

When you want to provide feedback on built code, drop a file into the feedback inbox:

```
.max-agents/feedback/inbox/
```

The file can be plain text describing a bug, a behavioral issue, a design change, or a rejected implementation. Then tell the Builder:

```
Process feedback
```

The Builder reads every file in the inbox, classifies each item (bug fix, spec change, new task, rejected output), and handles it appropriately:
- Bug fixes become new tasks inserted into the current phase
- Spec changes trigger a mini-architect re-spec of the affected tasks
- Rejected outputs cause the affected task to be re-run with the feedback as additional constraints

Processed files are moved from `inbox/` to `processed/` with a timestamp.

---

## Git Output

The Builder works on phase branches:

```
max-agents/phase-1
max-agents/phase-2
max-agents/phase-3
...
```

Each branch represents one phase of the task graph. When a phase completes, it is merged into the previous phase branch (not into main). The Launcher handles merging into main.

---

## Output Files

After each run (or when the Builder stops), two files are updated:

**`run-report.md`** — what happened in the last run: tasks completed, tasks failed, tasks parked (blocked by unmet dependencies or file conflicts), and why.

**`build-index.md`** — the cumulative index of all tasks completed across all runs: which files were written, which tests passed, which sub-agent handled each task.

Read `run-report.md` first when the Builder stops unexpectedly.

---

## When the Builder Stops

The Builder stops automatically when:

1. **Milestone reached** — all tasks up to the requested milestone are complete
2. **All remaining tasks are blocked** — every unfinished task has an unmet dependency or a file ownership conflict that cannot be resolved without new tasks completing first. Check `run-report.md` for the blocking chain.
3. **You intervene** — you can stop the Builder at any time by pressing Ctrl+C. It will finish the current sub-agent batch cleanly before stopping.

---

## Tips

**Do not interrupt mid-batch.** Wait for the Builder to reach a phase boundary before stopping or providing feedback. A mid-batch interruption can leave some tasks in the current phase complete and others incomplete, creating a partially-built state that is harder to recover from. The Builder will tell you when a phase boundary is reached.

**Check run-report.md when it stops.** The run report explains exactly which tasks are parked and why. "Parked" means the task could not run (blocked, not failed). Most parked tasks resolve automatically when their blocking tasks complete in the next batch.

**L-sized tasks are split automatically.** You will see the original L task disappear from the queue and be replaced by several S/M tasks. This is normal. The split is done by the mini-architect and does not require your input.

**Feedback files are plain text.** You do not need to follow any format. Write what you observed, what you expected, and (if you know it) which file or feature is affected. The Builder will classify and route it.

**Each milestone is deployable.** Do not build to V2 if you are not ready to use V1. Build to MVP, verify it works, then continue. Each milestone is a stable checkpoint.

---

## Self-Improvement Integration

The Builder records issues it encounters using `improvement.sh`:

```bash
bash <toolkit_root>/scripts/improvement.sh record <project_root> <severity> <category> "<description>"
```

- **severity**: `critical` or `non-critical`
- **category**: `workflow`, `agent`, `handoff`, or `task-spec`

**When to record:**
- A task spec was ambiguous and caused multiple fix cycles → `task-spec`
- A builder sub-agent type consistently stalls on a pattern → `agent`
- A task dependency graph had a cycle or missing edge that blocked a phase → `workflow`
- A handoff from the Architect was missing fields the Builder needs → `handoff`

**Milestone gate:** Before writing the handoff to the Launcher, run:

```bash
bash <toolkit_root>/scripts/improvement.sh milestone-check <project_root>
```

If critical unresolved issues exist, this exits with code 1 and prints them. Resolve them (via `propose` + `apply`) before generating the handoff.

Applied fixes are appended to `docs/troubleshooting.md` automatically.
