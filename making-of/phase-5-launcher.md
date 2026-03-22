# Phase 5: Launcher

**Status:** Q&A complete — ready to implement

## Overview

Build the Launcher agent — handles everything after the code is built: local verification, PR creation, deployment, DB management, and release notes. Strictly gated — every external/irreversible action requires explicit user approval.

## Why Phase 5

Launcher is the final step in the pipeline. It depends on Builder output and deals with external systems (GitHub, Vercel, Supabase). Higher risk of irreversible actions, so it has the most approval gates.

## Q&A Decisions

### Local Verification
- "Local verification" = get the app running locally so the user can manually test it. Could be a standalone app, localhost browser app, or whatever fits the project scope.
- The verifier builds and starts the app, confirms it's running, and presents the URL/entry point to the user.
- User always manually tests — verifier just confirms the app is up.

### Deployment Targets
- Deployment targets are **project-specific** — read from `.max-agents/config.json`, not hardcoded.
- Current targets in use: Vercel + Supabase, local npm/localhost.
- Future targets (planned but not built yet): standalone installable packages.
- Vercel has two stages: **dev/preview** (after PR creation) and **production** (after merge).
- Pre-flight auth check required before any external operation — verify CLI is authenticated before assuming it works.

### PR Workflow
- Phase branches (`max-agents/phase-N`) are internal implementation constructs — never exposed as PRs.
- **One PR per milestone** — Launcher merges all phase branches into a milestone branch, creates a single PR from that to main.
- For small projects (minor fix), there may be only one phase and one milestone — same flow applies.
- Launcher owns the full git workflow. Gates on user approval at each step. User says "proceed" and Launcher executes.

### Rollback
- If smoke tests fail after deployment: **report + summary + recommendation**, ask user for decision.
- No automatic rollback.

### Release Notes
- **Two outputs:**
  1. **Dev changelog** — for the user (Lauri). Tracks what changed, includes architectural decisions made during the build. Technical audience.
  2. **User-facing product notes** — for end users of the app. User has a habit of including these in the app itself.
- Published to GitHub Releases (gated) and/or written to file — user decides at the gate.

### Packaging
- npm packages and Docker images not in use yet — stub only, not implemented.

### Security / Credentials
- Launcher assumes CLIs are installed but does **not** assume they're authenticated.
- Pre-flight: verify each required CLI is authenticated before proceeding (e.g., `vercel whoami`, `supabase status`).
- If auth check fails: report which tool isn't connected and guide user to fix it before proceeding.
- Credentials via environment variables (never config files checked into repo).

---

## Architecture

```
LAUNCHER (Sonnet orchestrator)
├── local-verifier      — builds and starts app locally, confirms it's running
├── pr-manager          — merges phases → milestone branch, creates GitHub PR
├── vercel-deployer     — pre-flight auth, push to dev/preview then production
├── supabase-manager    — migrations, schema, data sync, DB verification
├── deployer            — generic deployer for non-Vercel targets (per config)
├── smoke-tester        — HTTP checks against deployed URL, reports + recommendation
├── release-noter       — dev changelog + user-facing product notes
└── [packager]          — STUB ONLY: npm/Docker for future standalone app support
```

---

## Execution Sequence

```
1. local-verifier builds and starts app locally
   └── GATE: "App running at [localhost:PORT]. Ready to create PR?"

2. pr-manager merges phase branches → milestone branch, creates PR
   └── GATE: "PR created at [URL]. Tell me when you want to proceed."

3. vercel-deployer pre-flight check + push to dev/preview
   └── GATE (before push): "Deploying to Vercel dev. Proceed?"
   └── smoke-tester hits preview URL
       └── GATE only if fail: "[N] tests failed. [Summary + suggestion]. What would you like to do?"

4. vercel-deployer pushes to production (after merge confirmed)
   └── GATE: "Deploy to production?" (irreversible)
   └── smoke-tester hits production URL
       └── GATE only if fail: "Production smoke tests failed. [Summary + suggestion]."

5. supabase-manager runs migrations + data sync
   └── GATE: "About to run these migrations on production DB: [list]. Proceed?"
   └── supabase-manager verifies DB operational after changes

6. release-noter generates both outputs
   └── GATE: "Here are the release note drafts. Publish to GitHub Releases?"
```

**Mandatory gates (always):** PR creation, Vercel dev deploy, production deploy, DB migrations, release publish.
**Conditional gates (failure only):** smoke test failures at dev and production.

---

## Sub-Agent Definitions

### Launcher (Orchestrator)
- **Model:** claude-sonnet-4-6
- **Tools:** All
- **Role:** Reads builder-to-launcher handoff. Coordinates the shipping sequence. Presents status at each gate. Never proceeds without user approval. Always shows exactly what it is about to do before doing it.
- **Key behavior:** Pre-flight checks before every external operation. Reports failures with a summary and a concrete suggestion. Never guesses on irreversible actions.

### Sub-Agent: local-verifier
- **Model:** claude-sonnet-4-6
- **Tools:** Bash, Read, Glob, Grep
- **Role:** Reads `build-index.md` to understand how to run the project. Executes the build command, then the start command. Confirms the app is accessible (local port, file path, or executable). Reports any build errors.
- **Output:** `verification-report.md` with: build status, start status, access URL/path, any errors.

### Sub-Agent: pr-manager
- **Model:** claude-sonnet-4-6
- **Tools:** Bash, Read, Write
- **Role:** Merges all `max-agents/phase-N` branches sequentially into a milestone branch (`max-agents/milestone-N`). Creates GitHub PR from milestone branch to main using `gh` CLI. PR description includes: milestone summary, features built, task list with task IDs, link to run-report, parked tasks if any.
- **Constraint:** Never pushes or creates PR without user approval. Shows PR description preview before creating.

### Sub-Agent: vercel-deployer
- **Model:** claude-sonnet-4-6
- **Tools:** Bash, Read, Write
- **Role:** Pre-flight: runs `vercel whoami` to verify auth. Reads Vercel project config from `.max-agents/config.json`. Deploys to dev/preview with `vercel`, then to production with `vercel --prod`. Shows exact command before running.
- **Constraint:** Never deploys without explicit user approval. Logs deploy URL and outcome to `deploy-log.md`.

### Sub-Agent: supabase-manager
- **Model:** claude-sonnet-4-6
- **Tools:** Bash, Read, Write
- **Role:** Pre-flight: runs `supabase status` to verify connection. Handles:
  - Schema management: runs pending migrations via `supabase db push`
  - Data sync: reads project-specific sync rules from `.max-agents/config.json` → syncs specified data from local Postgres to Supabase (or other configured source → target)
  - Verification: confirms DB is reachable and operational after changes
- **Constraint:** Never runs migrations without user approval. Lists all pending migrations before proceeding. Logs all operations to `db-log.md`.

### Sub-Agent: deployer
- **Model:** claude-sonnet-4-6
- **Tools:** Bash, Read, Write
- **Role:** Generic deployer for non-Vercel targets (Fly.io, Netlify, custom server, etc.). Reads deploy target and commands from `.max-agents/config.json`. Pre-flight auth check per target. Shows exact command before running.
- **Activation:** Only dispatched if config specifies a non-Vercel deploy target.

### Sub-Agent: smoke-tester
- **Model:** claude-sonnet-4-6
- **Tools:** Bash, Read, Write
- **Role:** Runs HTTP checks against a given URL (preview or production). Checks: health endpoint (if configured), key page loads (200 status), critical API endpoints from `api-contracts.json`. Reports: pass/fail per check, overall verdict, recommendation if failures found.
- **Output:** `smoke-test-results.md` with pass/fail per check + overall verdict.

### Sub-Agent: release-noter
- **Model:** claude-sonnet-4-6
- **Tools:** Read, Write, Bash
- **Role:** Reads `task-graph.json` (what was built), `run-report.md` (decisions + parked tasks), and `git log` (what changed). Produces two files:
  1. `dev-changelog.md` — technical log for the user: what changed, architectural decisions made, parked tasks, git commit range.
  2. `product-notes.md` — user-facing: features added, improvements, phrased for end users of the app.
- **Constraint:** Presents both drafts for user review before publishing to GitHub Releases.

### Sub-Agent: packager [STUB]
- **Model:** claude-sonnet-4-6
- **Tools:** Bash, Read, Write
- **Role:** STUB — not implemented. Placeholder for future npm package publishing and standalone app bundling. If activated, reports: "Packager not yet implemented. Coming in a future release."

---

## Output Structure

```
.max-agents/artifacts/launcher/
├── verification-report.md   # Local build + start results
├── pr-description.md        # Generated PR description (preview before creation)
├── deploy-log.md            # All deploy operations and outcomes
├── db-log.md                # All Supabase/DB operations and outcomes
├── smoke-test-results.md    # Post-deploy verification (dev + production)
├── dev-changelog.md         # Technical changelog for user
└── product-notes.md         # User-facing release notes
```

---

## Handoff Input (from Builder)

Reads `.max-agents/handoffs/builder-to-launcher.json`:
- `milestone_reached` — which milestone was built
- `phase_branches` — list of branches to merge into milestone PR
- `artifacts_produced` — run-report.md and build-index.md paths
- `parked_tasks` — tasks that didn't complete (included in PR description and release notes)

---

## Audit Logging

```bash
bash <toolkit_root>/scripts/audit-log.sh \
  log <project_root> launcher <action> <task> <status> [file]
```

Log these actions: `session-start`, `verification-complete`, `pr-created`, `deploy-dev`, `deploy-production`, `db-migrated`, `smoke-test-dev`, `smoke-test-production`, `release-notes-published`, `handoff-complete`.

---

## Rules

- Never proceed past a gate without explicit user approval.
- Never deploy, migrate, or publish without showing exactly what will happen first.
- Pre-flight auth check before every external CLI operation.
- If auth check fails: stop, report which tool is unauthenticated, guide user to fix.
- If smoke tests fail: report + summary + concrete suggestion. Never auto-rollback.
- Never modify `.claude/settings.json`.
- Never read or write `.env*` or `secrets/`.
- Stay within the project directory at all times.
