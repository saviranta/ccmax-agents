# Patcher Agent

The Patcher is a fast-track agent for small, self-contained changes. It collapses the full Prototyper → Architect → Builder → Launcher pipeline into a single interactive session by dispatching four lightweight sub-agents in sequence.

Patcher is **project-agnostic** — it can work on any project, not just max-agents initialized ones. At session start, you specify which project to work on, and Patcher locks all file operations to that project directory.

Use Patcher when you need to change a button label, fix a broken link, add a tooltip, update an error message, or make any other change you can describe in 1–2 sentences.

---

## What It Does

- Selects a project and locks all reads/writes to that directory
- Assesses the change to verify it fits Patcher scope (≤ 4 files, no schema changes, no new dependencies)
- Gathers context: existing patterns, design constraints, ADR rules (via Scout sub-agent — full mode only)
- Checks architectural alignment (via Arch-Checker sub-agent — full mode only)
- Makes the change with tests and build verification (via Patch-Builder sub-agent)
- Reviews the change with fresh eyes — re-runs tests, checks quality and security (via Patch-Reviewer sub-agent)
- Commits to a branch and creates a PR

If the change turns out to be too large, Patcher writes an escalation handover so you can continue with the Architect or Prototyper without losing work.

---

## Modes

| Mode | Condition | What's available |
|------|-----------|-----------------|
| **Full** | `.max-agents/config.json` + architect artifacts exist | All 4 sub-agents, audit logging, escalation handovers |
| **Config-only** | `.max-agents/config.json` exists, no architect artifacts | Patch-builder + patch-reviewer, security settings from config |
| **Standalone** | No `.max-agents/` at all | Patch-builder + patch-reviewer only |

---

## Input

In **full mode**, Patcher reads `.max-agents/config.json` and `.max-agents/artifacts/architect/` (conventions, ADRs, design system).

In **standalone mode**, Patcher works purely from the code — no conventions or ADRs to check against.

---

## How to Invoke

From anywhere:

```bash
bash ~/Library/CloudStorage/Dropbox/ClaudeFolder/agents-max/scripts/run-agent.sh patcher
```

Or from a specific project:

```bash
bash ~/Library/CloudStorage/Dropbox/ClaudeFolder/agents-max/scripts/run-agent.sh patcher /path/to/project
```

Or directly:

```bash
claude --append-system-prompt "$(cat ~/Library/CloudStorage/Dropbox/ClaudeFolder/agents-max/agents/patcher/CLAUDE.md)" --model opus
```

Patcher will ask which project to work on if it can't detect one. You can also switch projects mid-session by saying "switch project".

---

## Gates

Patcher has two explicit gates where it stops and waits for your approval:

1. **Scope confirmation** — after assessment, before any sub-agents run. Shows what will change and which sub-agents are needed.
2. **Ship confirmation** — after review passes. Shows the changes and asks whether to push and create a PR.

---

## Sub-Agents

| Sub-Agent | Model | Role |
|-----------|-------|------|
| Scout | Sonnet | Gathers existing patterns, design constraints, ADR rules |
| Arch-Checker | Sonnet | Verifies change fits existing architecture. PROCEED / PAUSE / ESCALATE |
| Patch-Builder | Sonnet | Makes the code change, writes tests, verifies build |
| Patch-Reviewer | Sonnet | Fresh-eyes review: re-runs tests, checks quality + security + design |

Scout and Arch-Checker are conditional — skipped for trivial changes or when no ADRs/design-system exist.

---

## Scope Limits

Patcher refuses changes that exceed these thresholds and escalates to the appropriate pipeline agent:

- More than 4 files modified
- Schema or migration changes
- New dependencies
- New external API integrations
- Protected files
- Product/UX decisions needed

---

## Escalation

When Patcher can't handle a change, it writes a handover document to `.max-agents/artifacts/patcher/`:

- **Architect escalation** — change is too large or has architectural implications
- **Prototyper escalation** — change requires product/UX decisions
- **Architect consult** (PAUSE) — small architectural question; run the Architect, get the answer, come back

---

## Output Files

```
.max-agents/artifacts/patcher/
├── patch-log-<timestamp>.md          # completed patch records
├── escalation-<timestamp>.md         # escalation handovers
└── architect-consult-<timestamp>.md  # architect questions (PAUSE path)
```

---

## Project Switching

You can switch projects at any time between phases by saying "switch project". Patcher will:
- Warn if there are uncommitted changes
- Reset session state
- Ask for the new project path

---

## Project Boundary

All file operations are restricted to the selected `PROJECT_ROOT`. Patcher will refuse to read or write files outside it. This applies to sub-agents too.

---

## Tips

**Start small.** If you're not sure whether something is Patcher-sized, try it. Patcher will tell you if it's too large and escalate cleanly.

**One change per session.** Patcher handles one change at a time. For multiple independent changes, run Patcher once per change.

**Full mode is best.** Running Architect at least once gives Patcher conventions and ADRs to check against, producing higher-quality patches. But standalone mode works fine for quick fixes.

**Review the PR.** Patcher creates PRs but does not deploy. Use the Launcher for deployment, or merge and deploy manually.
