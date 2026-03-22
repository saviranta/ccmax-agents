# Launcher Agent

The Launcher ships the built application. It runs a gated, sequential process from local verification through production deployment, including database migrations, smoke tests, and release notes. Every step requires your explicit approval before proceeding to the next.

---

## What It Does

- Verifies the build locally (type checks, linting, test suite)
- Opens a pull request from the phase branches into main
- Deploys to a preview environment and runs smoke tests
- Runs database migrations
- Deploys to production
- Generates release notes in two formats: technical changelog and user-facing product notes

The Launcher does not write application code. If it finds errors during local verification, it reports them for you to fix — it does not attempt to fix them itself.

---

## Input

The Launcher reads `.max-agents/handoffs/builder-to-launcher.json` automatically when it starts. It checks that:

- `phase_branches` is non-empty (at least one phase branch exists in git)
- The milestone indicated in the handoff matches your requested launch

If `phase_branches` is empty, the Builder has not completed any work and there is nothing to launch.

---

## Prerequisites

Before starting the Launcher, confirm:

- **Vercel CLI** is configured and authenticated (`vercel whoami` works)
- **Supabase CLI** is linked to the project (`supabase status` shows your project) — required if using Supabase
- Your `.env.production` file is populated with real values (not placeholders)
- You have appropriate permissions for the target deployment environment

The Launcher will check these at step 0 before the first gate. Missing prerequisites will block the process at that point rather than partway through.

---

## Six Steps

Each step is gated. The Launcher completes a step, shows you the results, and waits for your explicit "continue" before proceeding.

### Step 1: Local Verify

Runs the full local verification suite:
- TypeScript type check (`tsc --noEmit`)
- Lint (`eslint`)
- Unit test suite
- Build (`next build` or equivalent)

Output goes to `artifacts/launcher/verification-report.md`. If any check fails, the report shows exactly what failed and where. Fix the issues, then tell the Launcher to re-run verification.

### Step 2: Pull Request

Creates a PR from the top phase branch into main. The PR title and description are generated automatically from the task graph and run report.

Review the PR before approving this gate. You can add reviewers, request changes, or edit the description. Tell the Launcher to continue when the PR is ready to merge — it will merge it.

### Step 3: Preview Deploy

Deploys the merged code to the Vercel preview environment. Then runs the smoke test suite against the preview URL.

Output goes to `artifacts/launcher/smoke-test-results.md`. Smoke tests cover the critical paths from the user stories (login, core feature, navigation). If any smoke test fails, this is the last chance to catch environment-specific issues before production.

Do not skip this step. The most common pre-production failures are missing environment variables and misconfigured third-party service keys — both of which the smoke tests will surface.

### Step 4: Production Deploy

Deploys to the production Vercel environment. The Launcher will show you the production URL and wait for your confirmation before proceeding.

Output goes to `artifacts/launcher/deploy-log.md`.

### Step 5: DB Migrations

Runs any pending Supabase migrations against the production database. The Launcher shows you the migration list (which files, in what order) before running them.

**This step is irreversible.** Review the migration list carefully. If a migration drops a column or a table, confirm you have backed up any data you need.

If your project does not use Supabase or has no pending migrations, this step is skipped automatically.

### Step 6: Release Notes

Generates two release note documents:

**`dev-changelog.md`** — technical changelog for developers. Lists every task completed, files changed, ADR decisions implemented, and any known limitations or follow-up items.

**`product-notes.md`** — user-facing release notes. Written in plain language describing what users can now do. No technical implementation details. Suitable for posting in-app, on a changelog page, or in a product newsletter.

Both documents are saved to `artifacts/launcher/`. You can edit them before publishing.

---

## Output Files

```
.max-agents/artifacts/launcher/
  verification-report.md      — local check results (type errors, lint, test failures)
  deploy-log.md               — deployment output and production URL
  smoke-test-results.md       — smoke test pass/fail with details on failures
  dev-changelog.md            — technical release notes
  product-notes.md            — user-facing release notes
```

---

## How to Invoke

From your project directory (after the Builder has completed), launch the Launcher agent:

```bash
bash ~/Library/CloudStorage/Dropbox/ClaudeFolder/agents-max/scripts/run-agent.sh launcher
```

Or directly:

```bash
claude --append-system-prompt "$(cat ~/Library/CloudStorage/Dropbox/ClaudeFolder/agents-max/agents/launcher/CLAUDE.md)" --model sonnet
```

Then say something like "Start launch process."

The Launcher will confirm the handoff is valid and the prerequisites are met, then begin Step 1.

---

## Tips

**Do not skip the preview deploy.** Environment variable issues are the most common cause of production failures. They do not appear in local verification because local verification uses `.env.local`. The preview deploy uses the same environment variable configuration as production, so smoke test failures at this stage indicate real production risks.

**Review the migration list before Step 5.** The Launcher shows you every migration file that will run. Read them. A migration that looks correct in isolation may have unintended consequences when run against production data (e.g., a migration that sets a default value for a new column may take a long time to run on a large table and lock the table during that time).

**Both release note formats are generated automatically.** You do not need to write them. The Launcher derives the technical changelog from the task graph and the product notes from the user stories. Edit them after generation if the tone or content needs adjustment.

**Each gate is a decision point.** If something looks wrong at any gate — a failing test, a migration you did not expect, a smoke test failure — stop there and investigate before continuing. The sequential structure exists to catch problems before they reach production.

**Re-running a step.** If you need to re-run a step (e.g., after fixing a type error found in verification), tell the Launcher which step to re-run. It will not restart from the beginning — it picks up at the step you specify.
