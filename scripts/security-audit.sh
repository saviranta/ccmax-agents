#!/bin/bash
# security-audit.sh — Scan audit logs and git history for suspicious agent behavior
#
# Usage:
#   security-audit.sh <project_root>
#
# Checks for:
#   - File access outside project boundary
#   - Attempts to read/write secrets or env files
#   - Network requests to unexpected domains
#   - Modifications to security settings or agent definitions
#   - Suspicious bash commands (curl, wget, nc, eval, base64)
#   - Unexpected file types committed (binaries, scripts in unusual places)
#   - python3 -c or node -e with suspicious patterns

set -euo pipefail

PROJECT_ROOT="${1:-}"

if [[ -z "$PROJECT_ROOT" ]]; then
  echo "Usage: security-audit.sh <project_root>" >&2
  exit 1
fi

AUDIT_DIR="$PROJECT_ROOT/.max-agents/audit-log"
FINDINGS=0
WARNINGS=0

finding() {
  local severity="$1"
  local message="$2"
  echo "  [$severity] $message" >&2
  if [[ "$severity" == "CRITICAL" || "$severity" == "HIGH" ]]; then
    FINDINGS=$((FINDINGS + 1))
  else
    WARNINGS=$((WARNINGS + 1))
  fi
}

echo "" >&2
echo "╔══════════════════════════════════════╗" >&2
echo "║     agents-max · security audit      ║" >&2
echo "╚══════════════════════════════════════╝" >&2
echo "" >&2

# ─── 1. Scan audit logs for suspicious actions ───

echo "--- Audit Log Analysis ---" >&2

if [[ ! -d "$AUDIT_DIR" ]]; then
  echo "  No audit log directory found. Skipping log analysis." >&2
else
  # Combine all active + archived logs
  ALL_LOGS=$(cat "$AUDIT_DIR"/*.jsonl "$AUDIT_DIR"/archive/*.jsonl 2>/dev/null || true)

  if [[ -z "$ALL_LOGS" ]]; then
    echo "  No audit log entries found." >&2
  else
    # Check for path traversal in file fields
    traversals=$(echo "$ALL_LOGS" | AUDIT_LOGS=/dev/stdin python3 -c "
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        entry = json.loads(line)
        f = entry.get('file', '')
        if '..' in f or f.startswith('/'):
            print(f\"{entry.get('ts','?')} {entry.get('agent','?')} accessed: {f}\")
    except:
        pass
" 2>/dev/null || true)

    if [[ -n "$traversals" ]]; then
      while IFS= read -r line; do
        finding "HIGH" "Path traversal in audit log: $line"
      done <<< "$traversals"
    else
      echo "  OK: No path traversal attempts in logs" >&2
    fi

    # Check for env/secret file access in diffs
    secret_access=$(echo "$ALL_LOGS" | grep -i '"file".*\(\.env\|secret\|credential\|\.key\|\.pem\)' 2>/dev/null || true)
    if [[ -n "$secret_access" ]]; then
      finding "CRITICAL" "Agents accessed secret/env files (check diffs for content exposure)"
      echo "$secret_access" | head -5 >&2
    else
      echo "  OK: No secret/env file access detected" >&2
    fi
  fi
fi

# ─── 2. Scan git history for suspicious commits ───

echo "" >&2
echo "--- Git History Analysis ---" >&2

if [[ -d "$PROJECT_ROOT/.git" ]]; then
  cd "$PROJECT_ROOT"

  # Find all max-agents commits
  agent_commits=$(git log --all --oneline --grep='\[max-agents\]' 2>/dev/null || true)

  if [[ -z "$agent_commits" ]]; then
    echo "  No agent commits found." >&2
  else
    commit_count=$(echo "$agent_commits" | wc -l | tr -d ' ')
    echo "  Found $commit_count agent commit(s)" >&2

    # Check each commit for suspicious patterns
    while IFS= read -r commit_line; do
      hash=$(echo "$commit_line" | cut -d' ' -f1)

      # Get diff for this commit
      diff_content=$(git show --format="" "$hash" 2>/dev/null || true)

      # Check for hardcoded secrets patterns
      secrets_found=$(echo "$diff_content" | grep -iE '(api_key|secret_key|password|token|bearer)\s*[:=]\s*["\x27][^"\x27]{8,}' 2>/dev/null || true)
      if [[ -n "$secrets_found" ]]; then
        finding "CRITICAL" "Possible hardcoded secret in commit $hash"
        echo "$secrets_found" | head -3 >&2
      fi

      # Check for suspicious commands in code
      suspicious_cmds=$(echo "$diff_content" | grep -E '^\+.*\b(curl|wget|nc |netcat|base64 |openssl s_client)\b' 2>/dev/null || true)
      if [[ -n "$suspicious_cmds" ]]; then
        finding "HIGH" "Suspicious command added in commit $hash"
        echo "$suspicious_cmds" | head -3 >&2
      fi

      # Check for eval/exec patterns
      eval_patterns=$(echo "$diff_content" | grep -E '^\+.*(eval\(|exec\(|Function\(|child_process|subprocess\.call|os\.system)' 2>/dev/null || true)
      if [[ -n "$eval_patterns" ]]; then
        finding "MEDIUM" "Dynamic code execution added in commit $hash"
        echo "$eval_patterns" | head -3 >&2
      fi

      # Check for files outside expected locations
      files_changed=$(git show --format="" --name-only "$hash" 2>/dev/null || true)
      unexpected=$(echo "$files_changed" | grep -vE '^(src/|public/|lib/|app/|pages/|components/|styles/|tests?/|__tests__/|\.max-agents/|package|tsconfig|next\.config|tailwind|postcss|README|\.gitignore)' 2>/dev/null || true)
      if [[ -n "$unexpected" ]]; then
        finding "LOW" "Files changed in unexpected locations in commit $hash:"
        echo "$unexpected" | head -5 | sed 's/^/    /' >&2
      fi

    done <<< "$agent_commits"
  fi

  # Check for modifications to security files
  settings_changes=$(git log --all --oneline -- '.claude/settings.json' 2>/dev/null || true)
  if [[ -n "$settings_changes" ]]; then
    finding "CRITICAL" "settings.json was modified in git history:"
    echo "$settings_changes" >&2
  else
    echo "  OK: settings.json not modified" >&2
  fi

  # Check for binary files committed by agents
  binaries=$(git log --all --oneline --diff-filter=A --grep='\[max-agents\]' --name-only -- '*.exe' '*.dll' '*.so' '*.dylib' '*.bin' '*.dat' 2>/dev/null || true)
  if [[ -n "$binaries" ]]; then
    finding "HIGH" "Binary files committed by agents:"
    echo "$binaries" >&2
  else
    echo "  OK: No suspicious binary files committed" >&2
  fi
else
  echo "  No git repository found. Skipping git analysis." >&2
fi

# ─── 3. Check current state for anomalies ───

echo "" >&2
echo "--- Current State Analysis ---" >&2

# Check if settings.json has been weakened
if [[ -f "$PROJECT_ROOT/.claude/settings.json" ]]; then
  VALIDATE_FILE="$PROJECT_ROOT/.claude/settings.json" python3 -c "
import json, os
d = json.load(open(os.environ['VALIDATE_FILE']))

sandbox = d.get('sandbox', {})
if not sandbox.get('enabled'):
    print('CRITICAL:Sandbox is disabled')

fs = sandbox.get('filesystem', {})
deny = fs.get('denyRead', [])
if len(deny) < 3:
    print('MEDIUM:denyRead list has fewer than 3 entries — may have been stripped')

perms = d.get('permissions', {})
deny_perms = perms.get('deny', [])
if not any('.env' in r for r in deny_perms):
    print('HIGH:No .env deny rule in permissions')
if not any('settings.json' in r for r in deny_perms):
    print('HIGH:No settings.json protection in permissions')
if not any('agents-max' in r for r in deny_perms):
    print('MEDIUM:No agents-max script protection in permissions')

# Check for bypass flags
if d.get('allowManagedPermissionRulesOnly') is False:
    print('HIGH:allowManagedPermissionRulesOnly explicitly set to false')
" 2>/dev/null | while IFS= read -r issue; do
    severity="${issue%%:*}"
    message="${issue#*:}"
    finding "$severity" "$message"
  done

  echo "  OK: Security settings reviewed" >&2
fi

# Check for unexpected files in .claude/
if [[ -d "$PROJECT_ROOT/.claude" ]]; then
  unexpected_claude=$(find "$PROJECT_ROOT/.claude" -type f ! -name 'settings.json' ! -name 'CLAUDE.md' ! -name '*.md' -not -path '*/agents/*' 2>/dev/null || true)
  if [[ -n "$unexpected_claude" ]]; then
    finding "MEDIUM" "Unexpected files in .claude/:"
    echo "$unexpected_claude" | sed 's/^/    /' >&2
  fi
fi

# ─── Summary ───

echo "" >&2
echo "══════════════════════════════════════" >&2
echo "  Findings: $FINDINGS high/critical" >&2
echo "  Warnings: $WARNINGS medium/low" >&2
echo "══════════════════════════════════════" >&2

if [[ $FINDINGS -gt 0 ]]; then
  echo "" >&2
  echo "  ACTION REQUIRED: Review findings above before accepting agent work." >&2
  echo "" >&2
  exit 1
else
  echo "" >&2
  echo "  No critical issues found." >&2
  echo "" >&2
  exit 0
fi
