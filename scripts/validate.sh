#!/bin/bash
# validate.sh — Deterministic validation of project state (no LLM)
#
# Usage:
#   validate.sh <project_root>
#
# Checks config.json, state.json, task graph, handoffs, security.
# Exits 0 if valid, 1 if issues found.

set -euo pipefail

PROJECT_ROOT="${1:-}"

if [[ -z "$PROJECT_ROOT" ]]; then
  echo "Usage: validate.sh <project_root>" >&2
  exit 1
fi

MAX_DIR="$PROJECT_ROOT/.max-agents"
ERRORS=0
WARNINGS=0

error() {
  echo "  ERROR: $1" >&2
  ERRORS=$((ERRORS + 1))
}

warn() {
  echo "  WARN:  $1" >&2
  WARNINGS=$((WARNINGS + 1))
}

ok() {
  echo "  OK:    $1" >&2
}

# ─── Check .max-agents directory exists ───

echo "=== Validating project: $PROJECT_ROOT ===" >&2
echo "" >&2

if [[ ! -d "$MAX_DIR" ]]; then
  error ".max-agents/ directory not found"
  echo "" >&2
  echo "Result: $ERRORS error(s), $WARNINGS warning(s)" >&2
  exit 1
fi

# ─── Validate config.json ───

echo "--- config.json ---" >&2
CONFIG="$MAX_DIR/config.json"

if [[ ! -f "$CONFIG" ]]; then
  error "config.json not found"
else
  # Pass file path via env var to prevent injection
  for field in project_name project_root created_at mode; do
    val=$(VALIDATE_FILE="$CONFIG" VALIDATE_FIELD="$field" python3 -c "
import json, os
d = json.load(open(os.environ['VALIDATE_FILE']))
print(d.get(os.environ['VALIDATE_FIELD'], ''))
" 2>/dev/null || true)
    if [[ -z "$val" ]]; then
      error "config.json missing required field: $field"
    else
      ok "config.json.$field = $val"
    fi
  done

  for section in git agents security; do
    exists=$(VALIDATE_FILE="$CONFIG" VALIDATE_SECTION="$section" python3 -c "
import json, os
d = json.load(open(os.environ['VALIDATE_FILE']))
print('yes' if os.environ['VALIDATE_SECTION'] in d else 'no')
" 2>/dev/null || true)
    if [[ "$exists" != "yes" ]]; then
      error "config.json missing required section: $section"
    else
      ok "config.json.$section exists"
    fi
  done
fi

# ─── Validate state.json ───

echo "" >&2
echo "--- state.json ---" >&2
STATE="$MAX_DIR/state.json"

if [[ ! -f "$STATE" ]]; then
  error "state.json not found"
else
  for field in features tasks active_agents checkpoints; do
    exists=$(VALIDATE_FILE="$STATE" VALIDATE_FIELD="$field" python3 -c "
import json, os
d = json.load(open(os.environ['VALIDATE_FILE']))
print('yes' if os.environ['VALIDATE_FIELD'] in d else 'no')
" 2>/dev/null || true)
    if [[ "$exists" != "yes" ]]; then
      error "state.json missing required field: $field"
    else
      ok "state.json.$field exists"
    fi
  done

  # Validate task statuses, cycles, deps — single python call via env var
  validation_result=$(VALIDATE_FILE="$STATE" python3 -c "
import json, os

d = json.load(open(os.environ['VALIDATE_FILE']))
tasks = d.get('tasks', {})
errors = []

# Check valid statuses
valid = {'pending', 'in_progress', 'completed', 'blocked', 'parked', 'failed'}
for tid, t in tasks.items():
    s = t.get('status', '')
    if s and s not in valid:
        errors.append(f'INVALID_STATUS:{tid}={s}')

# Check dependency cycles (DFS)
deps = {tid: t.get('depends_on', []) for tid, t in tasks.items()}
WHITE, GRAY, BLACK = 0, 1, 2
color = {t: WHITE for t in deps}

def has_cycle(node, path):
    color[node] = GRAY
    for dep in deps.get(node, []):
        if dep not in color:
            continue
        if color[dep] == GRAY:
            errors.append(f'CYCLE:{\" -> \".join(path + [dep])}')
            return True
        if color[dep] == WHITE:
            if has_cycle(dep, path + [dep]):
                return True
    color[node] = BLACK
    return False

for t in deps:
    if color[t] == WHITE:
        has_cycle(t, [t])

# Check missing dependencies
task_ids = set(tasks.keys())
for tid, t in tasks.items():
    for dep in t.get('depends_on', []):
        if dep not in task_ids:
            errors.append(f'MISSING_DEP:{tid} depends on unknown {dep}')

print('|'.join(errors) if errors else '')
" 2>/dev/null || true)

  if [[ -n "$validation_result" ]]; then
    IFS='|' read -ra issues <<< "$validation_result"
    for issue in "${issues[@]}"; do
      error "$issue"
    done
  else
    ok "All task statuses valid"
    ok "No dependency cycles"
    ok "All dependencies reference existing tasks"
  fi
fi

# ─── Validate handoffs ───

echo "" >&2
echo "--- handoffs ---" >&2
HANDOFFS_DIR="$MAX_DIR/handoffs"

if [[ -d "$HANDOFFS_DIR" ]]; then
  handoff_count=0
  for hf in "$HANDOFFS_DIR"/*.json; do
    [[ -f "$hf" ]] || continue
    handoff_count=$((handoff_count + 1))

    hf_name=$(basename "$hf")
    hf_result=$(VALIDATE_FILE="$hf" python3 -c "
import json, os
d = json.load(open(os.environ['VALIDATE_FILE']))
missing = []
for field in ['id', 'from', 'to', 'timestamp', 'artifacts_produced']:
    val = d.get(field, '')
    if not val or val == []:
        missing.append(field)
print(','.join(missing) if missing else '')
" 2>/dev/null || true)

    if [[ -n "$hf_result" ]]; then
      error "$hf_name missing required fields: $hf_result"
    fi
  done
  ok "$handoff_count handoff(s) found"
else
  ok "No handoffs directory yet (OK for new project)"
fi

# ─── Validate directory structure ───

echo "" >&2
echo "--- directory structure ---" >&2

for dir in artifacts artifacts/prototyper artifacts/architect artifacts/builder artifacts/launcher artifacts/researcher handoffs audit-log checkpoints; do
  if [[ -d "$MAX_DIR/$dir" ]]; then
    ok "$dir/ exists"
  else
    warn "$dir/ missing"
  fi
done

# ─── Validate .claude/settings.json ───

echo "" >&2
echo "--- security ---" >&2
SETTINGS="$PROJECT_ROOT/.claude/settings.json"

if [[ ! -f "$SETTINGS" ]]; then
  warn ".claude/settings.json not found (security not configured)"
else
  sec_result=$(VALIDATE_FILE="$SETTINGS" python3 -c "
import json, os
d = json.load(open(os.environ['VALIDATE_FILE']))
issues = []

# Check sandbox enabled
sandbox = d.get('sandbox', {})
if not sandbox.get('enabled'):
    issues.append('WARN:Sandbox not enabled')

# Check deny rules exist
perms = d.get('permissions', {})
deny = perms.get('deny', [])
if not deny:
    issues.append('WARN:No permission deny rules')

# Check for overly broad bash permissions
allow = perms.get('allow', [])
for rule in allow:
    if 'Bash(python3 *)' in rule or 'Bash(node *)' in rule:
        issues.append('NOTE:Broad bash permission: ' + rule + ' (sandbox is primary boundary)')

print('|'.join(issues) if issues else 'OK')
" 2>/dev/null || true)

  if [[ "$sec_result" == "OK" ]]; then
    ok "Security configuration valid"
  else
    IFS='|' read -ra sec_issues <<< "$sec_result"
    for issue in "${sec_issues[@]}"; do
      if [[ "$issue" == WARN:* ]]; then
        warn "${issue#WARN:}"
      elif [[ "$issue" == NOTE:* ]]; then
        ok "${issue#NOTE:}"
      else
        error "$issue"
      fi
    done
  fi
fi

# ─── Summary ───

echo "" >&2
echo "=== Result: $ERRORS error(s), $WARNINGS warning(s) ===" >&2

if [[ $ERRORS -gt 0 ]]; then
  exit 1
else
  exit 0
fi
