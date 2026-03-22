# agents-max: Making Of

This folder contains the plans, decisions, and Q&A records for building the agents-max system.

## Process

Each phase follows this sequence:

1. **Plan** — Written plan document covering scope, architecture, deliverables
2. **Q&A session** — Detailed conversation with the user to refine requirements, define UX, scope, human-in-the-loop steps, restrictions, and security before any implementation begins
3. **Refined plan** — Updated plan incorporating Q&A decisions (appended to the phase document)
4. **Implementation** — Independent build of the phase based on the refined plan
5. **Review** — User validates the phase output before moving to the next

## Phase Documents

- [Phase 0: Architecture & Foundation](phase-0-architecture-foundation.md) ✅
- [Phase 1: Prototyper](phase-2-prototyper.md)
- [Phase 2: Architect](phase-3-architect.md)
- [Phase 3: Builder](phase-4-builder.md)
- [Phase 4: Launcher](phase-5-launcher.md)
- [Phase 5: Researcher](phase-1-researcher.md) (deferred — not in build pipeline)
- [Phase 6: Integration & Polish](phase-6-integration-polish.md)

## Research Sources

The initial plan was informed by analysis of:

- **Existing `/agents/` system** — single-writer manifest, file-based signals, builder specialization, Agent-SI self-improvement loop
- **everything-claude-code** (github.com/affaan-m/everything-claude-code) — 28 agents, structured handoffs, iterative retrieval pattern, model routing
- **MetaGPT** — role-based decomposition with typed artifact handoffs
- **ChatDev** — pairwise agent conversations with communication protocols
- **BMAD Method** — hyper-detailed stories bridging planning and execution
- **CCPM** — GitHub Issues as coordination backbone, file-based state persistence
- **CrewAI** — role/goal/backstory agent templates
- **Trail of Bits claude-code-config** — security-first defaults, sandbox configuration
- **Claude Code native features** — subagents, worktree isolation, sandbox, hooks, permission system
