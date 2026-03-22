# Troubleshooting Guide

_Entries are automatically appended when fixes are applied via `improvement.sh apply`._

_Last manual update: 2026-03-22_

---

## Handoff Issues

### Architect refuses to start / says handoff not found

**Symptom:** The Architect says it cannot find `prototyper-to-architect.json` or refuses to proceed.

**Cause:** The file is missing from `.max-agents/handoffs/`, or the file exists but has an empty `artifacts_produced` array (which the Architect treats as invalid).

**Fix:**

```bash
# Check whether the file exists
ls /path/to/project/.max-agents/handoffs/

# Run validate to see the full picture
bash /Users/lauri/Library/CloudStorage/Dropbox/ClaudeFolder/agents-max/scripts/validate.sh /path/to/project
```

If the file is missing: return to the Prototyper session and say "Generate the handoff now." If the file exists but `artifacts_produced` is empty, see the next entry.

---

### Handoff has empty artifacts_produced

**Symptom:** `.max-agents/handoffs/prototyper-to-architect.json` exists but `artifacts_produced` is `[]`.

**Cause:** The Prototyper was not explicitly asked to generate a handoff. It produced artifacts during the session but never wrote the handoff file, or wrote an incomplete one.

**Fix:** Open Claude Code in the project, start the Prototyper (`/prototyper`), and say:

```
Generate the handoff now.
```

The Prototyper will scan the `artifacts/prototyper/` directory, populate `artifacts_produced`, and write a complete handoff file. Verify the result:

```bash
cat /path/to/project/.max-agents/handoffs/prototyper-to-architect.json
```

---

### validate.sh fails with MISSING_DEP error

**Symptom:**

```
FAIL  task-graph: MISSING_DEP: task TASK-014 depends_on TASK-009 which does not exist
```

**Cause:** The task graph has a `depends_on` entry that references a task ID that was renamed, removed, or never created.

**Fix:** Have the Architect review and correct the task graph:

```
Open Claude Code, run /architect, say:
"task-graph.json has a broken dependency: TASK-014 depends on TASK-009 which does not exist. Fix it."
```

Alternatively, open `.max-agents/artifacts/architect/task-graph.json` directly and remove or correct the bad entry in the `depends_on` array for the affected task. Then re-run validate:

```bash
bash /Users/lauri/Library/CloudStorage/Dropbox/ClaudeFolder/agents-max/scripts/validate.sh /path/to/project
```

---

## Builder Failures

### Builder stalls / no progress for 10+ minutes

**Symptom:** The Builder session is running but nothing is completing. The dashboard's Running Now view shows the same tasks in the same state.

**Cause:** All remaining tasks are blocked — they depend on tasks that are parked or failed. The Builder has no unblocked tasks it can dispatch.

**Fix:**

```bash
# Check run-report for parked tasks
open /path/to/project/.max-agents/artifacts/builder/run-report.md
```

The run-report lists parked tasks and why they were parked. Unblocking usually means one of:

- The upstream failed task needs a manual fix (use Fix Mode: drop a note in `feedback/inbox/`)
- The task spec is ambiguous and needs clarification (re-open the Architect, have it update the task spec)
- The dependency chain is wrong (re-open the Architect, fix `task-graph.json`)

Also log the stall for tracking:

```bash
bash /Users/lauri/Library/CloudStorage/Dropbox/ClaudeFolder/agents-max/scripts/improvement.sh record /path/to/project high workflow "Builder stalled: all remaining tasks blocked by parked task TASK-007"
```

---

### Task parked after 3 fix cycles

**Symptom:** A task appears in run-report as `PARKED (max fix cycles reached)`. The bug-fixer sub-agent attempted to fix it three times and gave up.

**Cause:** The task spec does not have enough detail for the bug-fixer to solve the problem. The acceptance criteria may be vague, or the task is attempting to do too much.

**Fix:** Open the task spec:

```bash
open /path/to/project/.max-agents/artifacts/architect/task-specs/TASK-NNN.md
```

Add specific acceptance criteria, test cases, or implementation hints. Then use Fix Mode:

```bash
mkdir -p /path/to/project/feedback/inbox
# Write a note with explicit instructions
echo "TASK-NNN: the failing test is auth.test.ts line 44. The issue is X. Fix by doing Y." \
  > /path/to/project/feedback/inbox/task-nnn-instructions.txt
# Open Claude Code, run /builder, say "Process feedback"
```

---

### L-sized task not being split

**Symptom:** A large task is being attempted directly by a sub-agent instead of being split into smaller tasks by the mini-architect.

**Cause:** The task's `size` field in `task-graph.json` is not exactly `"L"`. Common mistake: it is set to `"Large"`, `"large"`, or `"XL"`, which the Builder does not recognize as the L-size trigger.

**Fix:** Open `task-graph.json` and find the task:

```bash
grep -A5 "TASK-NNN" /path/to/project/.max-agents/artifacts/architect/task-graph.json
```

Change the `size` value to exactly `"L"` (uppercase single letter). Then tell the Builder to re-process:

```
Resume the build. TASK-NNN's size has been corrected to L.
```

---

### Builder complaining about unresolved SCOPE+ tasks

**Symptom:** The Builder says it cannot proceed because there are SCOPE+ tasks awaiting approval.

**Cause:** During Fix Mode or a feature addition, the Builder identified tasks that expand the original scope. These require explicit user approval before implementation.

**Fix:** Ask the Builder to list the pending SCOPE+ tasks:

```
List all SCOPE+ tasks waiting for approval.
```

For each one, decide: approve (it gets added to the task graph and built), reject (it is removed), or defer (it is moved to a future milestone). Tell the Builder your decision for each task, then say "Proceed."

If the SCOPE+ tasks are large enough to require architecture decisions, route them back:

```
Defer SCOPE+ tasks to Architect for task graph extension.
```

---

## Validation Errors

### validate.sh: config.json missing required field: project_root

**Symptom:**

```
FAIL  config: missing required field: project_root
```

**Cause:** `config.json` was not generated by the init script (e.g., it was created manually or is from an old version), or a required field was accidentally deleted.

**Fix:** The safest fix is to re-run init in adopt mode — it will regenerate `config.json` without touching your existing artifacts or handoffs:

```bash
bash /Users/lauri/Library/CloudStorage/Dropbox/ClaudeFolder/agents-max/scripts/max-agents-init.sh
# Choose: adopt, /path/to/project
```

Alternatively, open `config.json` and add the missing field manually:

```json
{
  "project_root": "/absolute/path/to/project",
  "project_name": "My App",
  ...
}
```

---

### validate.sh: CYCLE: task-A -> task-B -> task-A

**Symptom:**

```
FAIL  task-graph: CYCLE detected: TASK-003 -> TASK-007 -> TASK-003
```

**Cause:** Circular dependency in the task graph. Task A depends on Task B, and Task B depends on Task A (directly or transitively).

**Fix:** Have the Architect fix it:

```
Open Claude Code, run /architect, say:
"task-graph.json has a circular dependency: TASK-003 -> TASK-007 -> TASK-003. Fix the depends_on entries."
```

Typically one of the two `depends_on` entries is wrong — one task doesn't actually need to wait for the other. The Architect will identify which dependency is incorrect and remove it. Re-run validate after the fix.

---

### validate.sh warns about .claude/settings.json not found

**Symptom:**

```
WARN  .claude/settings.json not found — tool permissions and network allowlist are not configured
```

**Cause:** The `.claude/` directory was not created by the init script, or `settings.json` was deleted.

**Fix:** Copy the template from the agents-max templates directory:

```bash
mkdir -p /path/to/project/.claude
cp /Users/lauri/Library/CloudStorage/Dropbox/ClaudeFolder/agents-max/templates/settings.json \
   /path/to/project/.claude/settings.json
```

Then open the file and customize the `network_allowlist` to include only the domains your project needs (e.g., your API host, Supabase URL, npm registry). Run `security-audit.sh` after editing:

```bash
bash /Users/lauri/Library/CloudStorage/Dropbox/ClaudeFolder/agents-max/scripts/security-audit.sh /path/to/project
```

---

## Deployment Issues

### Launcher fails local verification

**Symptom:** Launcher stops at step 1 and reports build or test failures in `verification-report.md`.

**Cause:** The build does not compile, the test suite has failures, or required environment variables are missing.

**Fix:**

```bash
open /path/to/project/.max-agents/artifacts/launcher/verification-report.md
```

Then reproduce the failure manually to see the full output:

```bash
cd /path/to/project
npm run build
```

Common causes:

- **TypeScript type errors** — fix the type errors, commit, tell Launcher to retry verification
- **Missing env vars** — check which variable is undefined, add it to `.env.local`, retry
- **Test failures** — these are usually the same failures the Builder left parked; use Fix Mode to resolve them before re-running Launcher

---

### Smoke tests fail on preview deploy

**Symptom:** Launcher step 3 (Preview Deploy) succeeds but the smoke tests against the preview URL fail.

**Cause:** An environment variable required at runtime is not set in the Vercel project settings for the preview environment.

**Fix:**

1. Check the smoke test output in `.max-agents/artifacts/launcher/smoke-test-preview.md` for the exact error (usually `undefined` or a 401/500 from an API call)
2. Identify the missing variable (e.g., `NEXT_PUBLIC_SUPABASE_URL`)
3. Add it in the Vercel dashboard: Project → Settings → Environment Variables → add for Preview environment
4. Trigger a new deployment (Vercel will redeploy from the same commit):

```bash
vercel --prebuilt
```

5. Tell the Launcher to re-run smoke tests against the new preview URL.

---

### Supabase migration fails

**Symptom:** Launcher step 5 (DB Migrations) fails with a SQL error.

**Cause:** The migration file contains a syntax error, references a table or column that doesn't exist yet, or runs operations in the wrong order.

**Fix:** Identify the failing migration file (Launcher will name it in the error output), then run the SQL manually in the Supabase SQL editor to see the detailed error:

1. Open Supabase dashboard → SQL Editor
2. Paste the contents of the failing migration file
3. Run it — Supabase will show the exact error line
4. Fix the SQL in the migration file
5. Tell the Launcher to retry the migration step

If the migration partially applied, you may need to write a compensating statement (e.g., `DROP TABLE IF EXISTS` or `ALTER TABLE ... DROP COLUMN`) before re-running.

---

## Dashboard Issues

### Web dashboard shows "Loading..." indefinitely

**Symptom:** Browser at `http://localhost:8787` shows "Loading..." and never populates.

**Cause:** `dashboard/data/snapshot.json` is not being written because `dashboard-server.sh` is not running, or it is running but cannot find the project path.

**Fix:** Make sure the server is running with the correct absolute project path:

```bash
bash /Users/lauri/Library/CloudStorage/Dropbox/ClaudeFolder/agents-max/scripts/dashboard-server.sh /absolute/path/to/project
```

Verify the snapshot file is being written:

```bash
ls -lt /Users/lauri/Library/CloudStorage/Dropbox/ClaudeFolder/agents-max/dashboard/data/
```

The `snapshot.json` file should have a modification time within the last few seconds. If it is not updating, check for errors in the server's terminal output.

---

### Terminal dashboard shows no active agents

**Symptom:** The Running Now view (key `1`) in the terminal dashboard shows an empty agent list.

**Cause:** `state.json`'s `active_agents` array is empty. This is correct behavior — `active_agents` is populated only while an agent session is actively running inside Claude Code.

**Fix:** No fix needed. When an agent (Prototyper, Architect, Builder, etc.) is actively running in a Claude Code session, it updates `active_agents` in `state.json` and the dashboard reflects that in real time. Between sessions, the field is empty.

If you expect an agent to be running and it is not appearing, check whether the Claude Code session is still open and whether the agent is still executing (it may have finished or hit a pause gate waiting for your input).

---

<!-- improvement.sh apply appends new entries below this line -->
