#!/bin/bash
# papertrail-sim.sh — Validates the full pipeline by simulating a complete handoff sequence
#
# Usage:
#   papertrail-sim.sh [--keep]
#
# Creates a temporary project, populates mock artifacts at each pipeline stage,
# validates handoffs with validate.sh, and reports friction points.
# Use --keep to preserve the temp project for inspection.

set -euo pipefail

KEEP=false
for arg in "$@"; do
  case "$arg" in --keep) KEEP=true ;; esac
done

AGENTS_MAX_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$AGENTS_MAX_DIR/scripts"
TEMPLATES_DIR="$AGENTS_MAX_DIR/templates"
CLAUDE_FOLDER="$HOME/Library/CloudStorage/Dropbox/ClaudeFolder"

# ─── Tracking ───

PASS=0
FAIL=0
FRICTION=()

pass()    { echo "  ✓ $1" >&2; PASS=$((PASS+1)); }
fail()    { echo "  ✗ $1 — $2" >&2; FAIL=$((FAIL+1)); FRICTION+=("$1: $2"); }
friction(){ echo "  ~ $1 — $2" >&2; FRICTION+=("FRICTION: $1: $2"); }
section() { echo "" >&2; echo "── $1 ──" >&2; }

# ─── Create temp dir (within ClaudeFolder for path containment) ───

SIM_DIR=$(mktemp -d "$CLAUDE_FOLDER/.papertrail-sim-XXXXXX")
echo "Simulation project: $SIM_DIR" >&2

cleanup() {
  if [[ "$KEEP" == true ]]; then
    echo "" >&2; echo "Project kept at: $SIM_DIR" >&2
  else
    rm -rf "$SIM_DIR"
    echo "" >&2; echo "Cleaned up." >&2
  fi
}
trap cleanup EXIT

# ════════════════════════════════════════════
# Step 1: Initialize
# ════════════════════════════════════════════

section "Step 1: Initialize"

# Create directory structure
mkdir -p \
  "$SIM_DIR/.max-agents/artifacts/prototyper" \
  "$SIM_DIR/.max-agents/artifacts/architect" \
  "$SIM_DIR/.max-agents/artifacts/builder" \
  "$SIM_DIR/.max-agents/artifacts/launcher" \
  "$SIM_DIR/.max-agents/artifacts/researcher" \
  "$SIM_DIR/.max-agents/artifacts/baseline" \
  "$SIM_DIR/.max-agents/handoffs" \
  "$SIM_DIR/.max-agents/audit-log/archive" \
  "$SIM_DIR/.max-agents/checkpoints" \
  "$SIM_DIR/.claude" \
  "$SIM_DIR/docs"

# Generate config.json
SIM_NAME="papertrail-sim" \
SIM_ROOT="$SIM_DIR" \
SIM_TOOLKIT="$AGENTS_MAX_DIR" \
SIM_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
SIM_CONFIG_TEMPLATE="$TEMPLATES_DIR/config.json" \
python3 -c "
import json, os
from datetime import datetime
config = json.load(open(os.environ['SIM_CONFIG_TEMPLATE']))
config['project_name'] = os.environ['SIM_NAME']
config['project_description'] = 'Papertrail simulation'
config['project_root'] = os.environ['SIM_ROOT']
config['toolkit_root'] = os.environ['SIM_TOOLKIT']
config['created_at'] = os.environ['SIM_TS']
config['mode'] = 'new'
out = os.path.join(os.environ['SIM_ROOT'], '.max-agents', 'config.json')
with open(out, 'w') as f:
    json.dump(config, f, indent=2)
"

# Copy state.json and settings.json templates
cp "$TEMPLATES_DIR/state.json"    "$SIM_DIR/.max-agents/state.json"
cp "$TEMPLATES_DIR/settings.json" "$SIM_DIR/.claude/settings.json"

# Write minimal CLAUDE.md
cat > "$SIM_DIR/.claude/CLAUDE.md" <<'CLAUDEMD'
# Papertrail Simulation
This is a test project.
CLAUDEMD

# Git init and initial commit
git -C "$SIM_DIR" init -q
git -C "$SIM_DIR" add -A
git -C "$SIM_DIR" -c user.email="sim@papertrail" -c user.name="papertrail-sim" \
  commit -q -m "sim: init"

# Validate
val_out=$("$SCRIPTS_DIR/validate.sh" "$SIM_DIR" 2>&1 || true)
if echo "$val_out" | grep -q "^=== Result: 0 error"; then
  pass "init → validate"
else
  fail "init → validate" "$(echo "$val_out" | grep -E 'ERROR:|Result:' | head -5 | tr '\n' '; ')"
fi

# ════════════════════════════════════════════
# Step 2: Prototyper
# ════════════════════════════════════════════

section "Step 2: Prototyper"

mkdir -p "$SIM_DIR/.max-agents/artifacts/prototyper/user-stories"

# vision.md
cat > "$SIM_DIR/.max-agents/artifacts/prototyper/vision.md" <<'EOF'
# Vision: Task Manager App

**Problem:** Teams lose track of work items across disconnected tools, causing missed deadlines and duplicated effort.

**Solution:** A lightweight, keyboard-first task manager with real-time sync, structured task statuses, and a minimal UI that stays out of the way.

**Target Users:** Small engineering teams (3–12 people) who prefer CLI-adjacent workflows.

**Success Criteria:**
- Users can create, assign, and close tasks in under 5 seconds
- All state is persisted and synced within 2 seconds
- Zero config required to get started
EOF

# design-constraints.md
cat > "$SIM_DIR/.max-agents/artifacts/prototyper/design-constraints.md" <<'EOF'
# Design Constraints

## Stack Boundaries
- TypeScript throughout (strict mode)
- Next.js 14 App Router — no Pages Router
- Tailwind CSS for styling; no CSS-in-JS
- Supabase for auth + realtime + persistence

## UX Constraints
- Mobile-first responsive layout
- No external icon libraries (use inline SVGs)
- Keyboard shortcuts required for all primary actions
- Accessible: WCAG 2.1 AA minimum

## Scope Limits (MVP)
- Single workspace per user
- No file attachments
- No integrations (GitHub, Slack, etc.) in phase-1
EOF

# user-stories/us-001.md
cat > "$SIM_DIR/.max-agents/artifacts/prototyper/user-stories/us-001.md" <<'EOF'
# US-001: Create a Task

**As a** logged-in user
**I want to** create a new task with a title and optional description
**So that** I can track a unit of work

## Acceptance Criteria
- [ ] Pressing `n` from the task list opens a creation modal
- [ ] Title is required; description is optional
- [ ] Submitting creates the task in status `pending`
- [ ] New task appears at the top of the list immediately
- [ ] Error state shown if creation fails
EOF

# user-stories/us-002.md
cat > "$SIM_DIR/.max-agents/artifacts/prototyper/user-stories/us-002.md" <<'EOF'
# US-002: Update Task Status

**As a** logged-in user
**I want to** change a task's status (pending → in_progress → done)
**So that** the team can see real-time progress

## Acceptance Criteria
- [ ] Status chip is clickable and cycles through valid transitions
- [ ] Keyboard shortcut `s` toggles status on the focused task
- [ ] Status change is reflected in real-time for all viewers
- [ ] Invalid transitions (e.g., done → pending) are blocked with explanation
EOF

# prototyper-to-architect handoff
SIM_TS2="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
SIM_HO_OUT="$SIM_DIR/.max-agents/handoffs/prototyper-to-architect.json" \
python3 -c "
import json, os, uuid
hf = {
    'id': str(uuid.uuid4()),
    'from': 'prototyper',
    'to': 'architect',
    'timestamp': os.environ['SIM_TS2'],
    'status': 'pending',
    'artifacts_produced': [
        '.max-agents/artifacts/prototyper/vision.md',
        '.max-agents/artifacts/prototyper/design-constraints.md',
        '.max-agents/artifacts/prototyper/user-stories/us-001.md',
        '.max-agents/artifacts/prototyper/user-stories/us-002.md'
    ],
    'decisions_made': [
        'Stack: Next.js 14 + Supabase + Tailwind + TypeScript strict',
        'MVP scoped to single workspace, no integrations',
        'Keyboard-first UX with WCAG 2.1 AA compliance'
    ],
    'open_questions': [
        'Should tasks support sub-tasks in phase-1 or defer to phase-2?',
        'Real-time via Supabase channels or polling fallback needed?'
    ],
    'recommended_next_steps': [
        'Define file/folder conventions and module boundaries',
        'Decompose user stories into implementable tasks',
        'Establish error-handling and loading-state patterns'
    ],
    'review': {
        'reviewed_by': 'papertrail-sim',
        'reviewed_at': os.environ['SIM_TS2'],
        'issues_found': [],
        'verdict': 'approved',
        'user_decision': 'proceed'
    }
}
with open(os.environ['SIM_HO_OUT'], 'w') as f:
    json.dump(hf, f, indent=2)
"

# Audit log
bash "$SCRIPTS_DIR/audit-log.sh" log "$SIM_DIR" prototyper handoff-generated "Prototyper handoff" success

# Validate
val_out=$("$SCRIPTS_DIR/validate.sh" "$SIM_DIR" 2>&1 || true)
if echo "$val_out" | grep -q "^=== Result: 0 error"; then
  pass "prototyper → validate"
else
  fail "prototyper → validate" "$(echo "$val_out" | grep -E 'ERROR:|Result:' | head -5 | tr '\n' '; ')"
fi

# Check handoff required fields
hf_check=$(SIM_HF="$SIM_DIR/.max-agents/handoffs/prototyper-to-architect.json" python3 -c "
import json, os
d = json.load(open(os.environ['SIM_HF']))
missing = []
for field in ['id', 'from', 'to', 'timestamp', 'artifacts_produced']:
    val = d.get(field, '')
    if not val or val == []:
        missing.append(field)
print(','.join(missing) if missing else 'ok')
" 2>/dev/null || true)

if [[ "$hf_check" == "ok" ]]; then
  pass "prototyper handoff fields complete"
else
  fail "prototyper handoff fields" "missing: $hf_check"
fi

# ════════════════════════════════════════════
# Step 3: Architect
# ════════════════════════════════════════════

section "Step 3: Architect"

mkdir -p \
  "$SIM_DIR/.max-agents/artifacts/architect/architecture" \
  "$SIM_DIR/.max-agents/artifacts/architect/task-specs"

# architecture/overview.md
cat > "$SIM_DIR/.max-agents/artifacts/architect/architecture/overview.md" <<'EOF'
# Architecture Overview

## Module Map

```
src/
  app/              # Next.js App Router pages and layouts
    (auth)/         # Auth-gated routes
    api/            # Route handlers
  lib/
    auth.ts         # Supabase auth helpers
    tasks.ts        # Task CRUD + realtime subscription
    db.ts           # Typed Supabase client
  components/
    TaskList.tsx
    TaskModal.tsx
    StatusChip.tsx
  types/
    index.ts        # Shared TypeScript types
tests/
  integration/
    phase-1.test.ts
```

## Data Flow
1. Client authenticates via Supabase Auth (OAuth or magic link)
2. Task mutations go through `/api/tasks` route handlers
3. Realtime updates pushed via Supabase channel subscription in `lib/tasks.ts`
4. All DB access is typed via generated Supabase types

## Key Constraints
- Server components fetch directly; client components use SWR + realtime
- No shared mutable state outside Supabase
EOF

# conventions.md
cat > "$SIM_DIR/.max-agents/artifacts/architect/conventions.md" <<'EOF'
# Coding Conventions

## TypeScript
- `strict: true` in tsconfig — no `any`, no non-null assertions without comment
- Prefer `type` over `interface` for data shapes; `interface` for extension points
- All async functions must handle errors explicitly (no unhandled rejections)

## File Naming
- Components: PascalCase (`TaskList.tsx`)
- Utilities/lib: camelCase (`auth.ts`)
- Test files: colocate with `*.test.ts` suffix

## Git
- Commit prefix: `[max-agents]` for agent commits
- Branch pattern: `max-agents/<phase>-<description>`
- Never commit `.env*` or generated files outside `src/`

## Testing
- Unit tests for all `lib/` functions
- Integration tests per phase in `tests/integration/`
- Playwright for E2E (deferred to post-MVP)
EOF

# task-graph.json
SIM_TG_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
SIM_TG_OUT="$SIM_DIR/.max-agents/artifacts/architect/task-graph.json" \
python3 -c "
import json, os
tg = {
    'version': '1.0',
    'project': 'papertrail-sim',
    'generated_by': 'task-decomposer',
    'generated_at': os.environ['SIM_TG_TS'],
    'milestones': {
        'mvp': {
            'description': 'Core features',
            'phases': ['phase-1']
        }
    },
    'phases': [
        {
            'id': 'phase-1',
            'name': 'Core',
            'milestone': 'mvp',
            'tasks': ['task-001', 'task-002'],
            'integration_test_tasks': ['task-int-001'],
            'gate': 'All phase-1 tasks done'
        }
    ],
    'tasks': {
        'task-001': {
            'title': 'Auth setup',
            'assigned_to': 'builder-api',
            'size': 'S',
            'milestone': 'mvp',
            'depends_on': [],
            'owns_files': ['src/lib/auth.ts'],
            'requires': [],
            'may_need': [],
            'spec_file': 'task-specs/task-001.md',
            'status': 'pending',
            'phase': 'phase-1',
            'type': 'implementation'
        },
        'task-002': {
            'title': 'Task CRUD API',
            'assigned_to': 'builder-api',
            'size': 'M',
            'milestone': 'mvp',
            'depends_on': ['task-001'],
            'owns_files': ['src/lib/tasks.ts'],
            'requires': [],
            'may_need': [],
            'spec_file': 'task-specs/task-002.md',
            'status': 'pending',
            'phase': 'phase-1',
            'type': 'implementation'
        },
        'task-int-001': {
            'title': 'Integration tests: phase-1',
            'assigned_to': 'builder-composer',
            'size': 'S',
            'milestone': 'mvp',
            'depends_on': ['task-001', 'task-002'],
            'owns_files': ['tests/integration/phase-1.test.ts'],
            'requires': [],
            'may_need': [],
            'spec_file': 'task-specs/task-int-001.md',
            'status': 'pending',
            'phase': 'phase-1',
            'type': 'integration-test'
        }
    }
}
with open(os.environ['SIM_TG_OUT'], 'w') as f:
    json.dump(tg, f, indent=2)
"

# task specs
cat > "$SIM_DIR/.max-agents/artifacts/architect/task-specs/task-001.md" <<'EOF'
# Task 001: Auth Setup

**Assigned to:** builder-api
**Size:** S | **Phase:** phase-1 | **Type:** implementation

## Deliverable
`src/lib/auth.ts` — Supabase auth helper with `getSession()`, `signIn()`, `signOut()`.

## Acceptance
- `getSession()` returns typed session or null
- `signIn()` triggers Supabase OAuth flow
- All functions are exported with JSDoc comments
EOF

cat > "$SIM_DIR/.max-agents/artifacts/architect/task-specs/task-002.md" <<'EOF'
# Task 002: Task CRUD API

**Assigned to:** builder-api
**Size:** M | **Phase:** phase-1 | **Type:** implementation
**Depends on:** task-001

## Deliverable
`src/lib/tasks.ts` — createTask, updateTask, deleteTask, subscribeTasks.

## Acceptance
- All mutations validate input with zod
- subscribeTasks returns an unsubscribe function
- Errors bubble as typed `AppError`
EOF

cat > "$SIM_DIR/.max-agents/artifacts/architect/task-specs/task-int-001.md" <<'EOF'
# Task INT-001: Integration Tests Phase-1

**Assigned to:** builder-composer
**Size:** S | **Phase:** phase-1 | **Type:** integration-test
**Depends on:** task-001, task-002

## Deliverable
`tests/integration/phase-1.test.ts` — end-to-end integration tests for auth + task CRUD.

## Acceptance
- Tests run with `npm test` without additional setup
- Auth flow and CRUD round-trip are both covered
- All tests pass green
EOF

# architect-to-builder handoff
SIM_TS3="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
SIM_HO_OUT="$SIM_DIR/.max-agents/handoffs/architect-to-builder.json" \
SIM_TG_PATH="$SIM_DIR/.max-agents/artifacts/architect/task-graph.json" \
python3 -c "
import json, os, uuid
hf = {
    'id': str(uuid.uuid4()),
    'from': 'architect',
    'to': 'builder',
    'timestamp': os.environ['SIM_TS3'],
    'status': 'pending',
    'artifacts_produced': [
        '.max-agents/artifacts/architect/architecture/overview.md',
        '.max-agents/artifacts/architect/conventions.md',
        '.max-agents/artifacts/architect/task-graph.json',
        '.max-agents/artifacts/architect/task-specs/task-001.md',
        '.max-agents/artifacts/architect/task-specs/task-002.md',
        '.max-agents/artifacts/architect/task-specs/task-int-001.md'
    ],
    'decisions_made': [
        'Module structure finalized (see architecture/overview.md)',
        'TypeScript strict mode enforced via tsconfig',
        'Task graph decomposed: 2 impl tasks + 1 integration test task in phase-1'
    ],
    'open_questions': [
        'Confirm Supabase project credentials are available in .env.local before builder starts'
    ],
    'recommended_next_steps': [
        'Builder runs tasks in dependency order: task-001 → task-002 → task-int-001',
        'Each task committed with [max-agents] prefix on branch max-agents/phase-1'
    ],
    'stack': {
        'framework': 'Next.js 14 (App Router)',
        'language': 'TypeScript (strict)',
        'styling': 'Tailwind CSS',
        'backend': 'Supabase',
        'testing': 'Jest + Playwright (deferred)'
    },
    'review': {
        'reviewed_by': 'papertrail-sim',
        'reviewed_at': os.environ['SIM_TS3'],
        'issues_found': [],
        'verdict': 'approved',
        'user_decision': 'proceed'
    }
}
with open(os.environ['SIM_HO_OUT'], 'w') as f:
    json.dump(hf, f, indent=2)
"

# Audit log
bash "$SCRIPTS_DIR/audit-log.sh" log "$SIM_DIR" architect handoff-generated "Architect handoff" success

# Validate
val_out=$("$SCRIPTS_DIR/validate.sh" "$SIM_DIR" 2>&1 || true)
if echo "$val_out" | grep -q "^=== Result: 0 error"; then
  pass "architect → validate"
else
  fail "architect → validate" "$(echo "$val_out" | grep -E 'ERROR:|Result:' | head -5 | tr '\n' '; ')"
fi

# Check handoff required fields
hf_check=$(SIM_HF="$SIM_DIR/.max-agents/handoffs/architect-to-builder.json" python3 -c "
import json, os
d = json.load(open(os.environ['SIM_HF']))
missing = []
for field in ['id', 'from', 'to', 'timestamp', 'artifacts_produced']:
    val = d.get(field, '')
    if not val or val == []:
        missing.append(field)
print(','.join(missing) if missing else 'ok')
" 2>/dev/null || true)

if [[ "$hf_check" == "ok" ]]; then
  pass "architect handoff fields complete"
else
  fail "architect handoff fields" "missing: $hf_check"
fi

# ════════════════════════════════════════════
# Step 4: Builder
# ════════════════════════════════════════════

section "Step 4: Builder"

# Update all task statuses to "done" in task-graph.json
SIM_TG_PATH="$SIM_DIR/.max-agents/artifacts/architect/task-graph.json" \
python3 -c "
import json, os
path = os.environ['SIM_TG_PATH']
with open(path) as f:
    tg = json.load(f)
for tid in tg.get('tasks', {}):
    tg['tasks'][tid]['status'] = 'done'
with open(path, 'w') as f:
    json.dump(tg, f, indent=2)
"

# run-report.md
cat > "$SIM_DIR/.max-agents/artifacts/builder/run-report.md" <<'EOF'
# Builder Run Report

**Phase:** phase-1
**Milestone:** mvp
**Branch:** max-agents/phase-1

## Tasks Completed

| Task | Title | Agent | Status |
|------|-------|-------|--------|
| task-001 | Auth setup | builder-api | done |
| task-002 | Task CRUD API | builder-api | done |
| task-int-001 | Integration tests: phase-1 | builder-composer | done |

## Summary
- 3/3 tasks completed
- 0 fix cycles required
- All integration tests passing
- No stalls or blocked tasks

## Files Created
- `src/lib/auth.ts` — Supabase auth helpers
- `src/lib/tasks.ts` — Task CRUD + realtime
- `tests/integration/phase-1.test.ts` — Phase-1 integration tests
EOF

# build-index.md
cat > "$SIM_DIR/.max-agents/artifacts/builder/build-index.md" <<'EOF'
# Build Index

## Source Files

### src/lib/auth.ts
Supabase auth helpers: `getSession()`, `signIn()`, `signOut()`. Typed session handling with error propagation.

### src/lib/tasks.ts
Task CRUD operations (`createTask`, `updateTask`, `deleteTask`) and `subscribeTasks()` realtime subscription. All mutations validated with zod. Errors typed as `AppError`.

## Test Files

### tests/integration/phase-1.test.ts
Integration tests covering auth round-trip and full task CRUD lifecycle. Runs with `npm test`.
EOF

# builder-to-launcher handoff
SIM_TS4="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
SIM_HO_OUT="$SIM_DIR/.max-agents/handoffs/builder-to-launcher.json" \
python3 -c "
import json, os, uuid
hf = {
    'id': str(uuid.uuid4()),
    'from': 'builder',
    'to': 'launcher',
    'timestamp': os.environ['SIM_TS4'],
    'status': 'pending',
    'artifacts_produced': [
        '.max-agents/artifacts/builder/run-report.md',
        '.max-agents/artifacts/builder/build-index.md'
    ],
    'decisions_made': [
        'All phase-1 tasks completed without fix cycles',
        'Integration tests passing on branch max-agents/phase-1'
    ],
    'open_questions': [
        'Confirm deployment environment variables are set in Vercel dashboard'
    ],
    'recommended_next_steps': [
        'Launcher merges max-agents/phase-1 into main',
        'Deploy to Vercel preview, run smoke tests',
        'Tag release v0.1.0-mvp'
    ],
    'milestone_reached': 'mvp',
    'phase_branches': ['max-agents/phase-1'],
    'parked_tasks': [],
    'review': {
        'reviewed_by': 'papertrail-sim',
        'reviewed_at': os.environ['SIM_TS4'],
        'issues_found': [],
        'verdict': 'approved',
        'user_decision': 'proceed'
    }
}
with open(os.environ['SIM_HO_OUT'], 'w') as f:
    json.dump(hf, f, indent=2)
"

# Audit log
bash "$SCRIPTS_DIR/audit-log.sh" log "$SIM_DIR" builder handoff-generated "Builder handoff" success

# Validate
val_out=$("$SCRIPTS_DIR/validate.sh" "$SIM_DIR" 2>&1 || true)
if echo "$val_out" | grep -q "^=== Result: 0 error"; then
  pass "builder → validate"
else
  fail "builder → validate" "$(echo "$val_out" | grep -E 'ERROR:|Result:' | head -5 | tr '\n' '; ')"
fi

# ════════════════════════════════════════════
# Step 5: Launcher pre-flight
# ════════════════════════════════════════════

section "Step 5: Launcher pre-flight"

# Check each handoff file exists
for hf_name in prototyper-to-architect architect-to-builder builder-to-launcher; do
  hf_path="$SIM_DIR/.max-agents/handoffs/${hf_name}.json"
  if [[ -f "$hf_path" ]]; then
    pass "handoff exists: $hf_name"
  else
    fail "handoff exists: $hf_name" "file not found: $hf_path"
  fi
done

# Check audit log has entries (count lines in today's .jsonl)
TODAY_LOG="$SIM_DIR/.max-agents/audit-log/$(date -u +%Y-%m-%d).jsonl"
if [[ -f "$TODAY_LOG" ]]; then
  audit_count=$(wc -l < "$TODAY_LOG" | tr -d ' ')
  if [[ "$audit_count" -gt 0 ]]; then
    pass "audit log has $audit_count entries"
  else
    fail "audit log entries" "log file exists but is empty"
  fi
else
  fail "audit log entries" "today's log file not found: $TODAY_LOG"
fi

# Check task graph: all tasks have status == "done"
SIM_TG_PATH="$SIM_DIR/.max-agents/artifacts/architect/task-graph.json" \
python3 -c "
import json, os, sys
path = os.environ['SIM_TG_PATH']
with open(path) as f:
    tg = json.load(f)
not_done = [tid for tid, t in tg.get('tasks', {}).items() if t.get('status') != 'done']
if not_done:
    print('NOT_DONE:' + ','.join(not_done))
else:
    print('ok')
" 2>/dev/null | {
  read -r tg_result
  if [[ "$tg_result" == "ok" ]]; then
    pass "task graph: all tasks done"
  else
    fail "task graph: all tasks done" "${tg_result#NOT_DONE:}"
  fi
}

# Check phase_branches non-empty in builder-to-launcher handoff
pb_check=$(SIM_HF="$SIM_DIR/.max-agents/handoffs/builder-to-launcher.json" python3 -c "
import json, os
d = json.load(open(os.environ['SIM_HF']))
pb = d.get('phase_branches', [])
print('ok' if pb else 'empty')
" 2>/dev/null || true)

if [[ "$pb_check" == "ok" ]]; then
  pass "builder handoff: phase_branches populated"
else
  fail "builder handoff: phase_branches" "phase_branches is empty"
fi

# Run security-audit.sh (failures are friction, not fail — expected in sim)
sec_out=$("$SCRIPTS_DIR/security-audit.sh" "$SIM_DIR" 2>&1 || true)
if echo "$sec_out" | grep -q "No critical issues found"; then
  pass "security-audit: no critical issues"
else
  friction "security-audit" "$(echo "$sec_out" | grep -E '^\s*\[(CRITICAL|HIGH)\]' | head -5 | tr '\n' '; ' | sed 's/; $//')"
fi

# ════════════════════════════════════════════
# Summary
# ════════════════════════════════════════════

echo "" >&2
echo "══════════════════════════" >&2
echo "  Simulation Results" >&2
echo "══════════════════════════" >&2
printf "  Passed:  %d\n" "$PASS" >&2
printf "  Failed:  %d\n" "$FAIL" >&2
printf "  Friction: %d\n" "${#FRICTION[@]}" >&2

if [[ ${#FRICTION[@]} -gt 0 ]]; then
  echo "" >&2
  echo "  Details:" >&2
  for f in "${FRICTION[@]}"; do
    echo "    · $f" >&2
  done
fi
echo "" >&2

[[ $FAIL -eq 0 ]]
