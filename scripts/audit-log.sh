#!/bin/bash
# audit-log.sh — Append entries to the project audit log (JSONL with diffs)
#
# Usage:
#   audit-log.sh log <project_root> <agent> <action> <task> <status> [file] [turns_used]
#   audit-log.sh archive <project_root>
#   audit-log.sh prune <project_root>
#
# Examples:
#   audit-log.sh log /path/to/project builder-frontend edit task-012 success src/App.tsx 3
#   audit-log.sh archive /path/to/project
#   audit-log.sh prune /path/to/project

set -euo pipefail

COMMAND="${1:-}"
PROJECT_ROOT="${2:-}"

if [[ -z "$COMMAND" || -z "$PROJECT_ROOT" ]]; then
  echo "Usage: audit-log.sh <log|archive|prune> <project_root> [args...]" >&2
  exit 1
fi

# Path containment check
REAL_ROOT=$(realpath "$PROJECT_ROOT" 2>/dev/null || echo "$PROJECT_ROOT")
ALLOWED_BASE="$HOME/Library/CloudStorage/Dropbox/ClaudeFolder"
if [[ "$REAL_ROOT" != "$ALLOWED_BASE"/* ]]; then
  echo "Error: Project root must be within ClaudeFolder" >&2
  exit 1
fi

AUDIT_DIR="$PROJECT_ROOT/.max-agents/audit-log"
ARCHIVE_DIR="$AUDIT_DIR/archive"
TODAY=$(date -u +%Y-%m-%d)
LOG_FILE="$AUDIT_DIR/$TODAY.jsonl"

log_entry() {
  local agent="${3:-}"
  local action="${4:-}"
  local task="${5:-}"
  local status="${6:-}"
  local file="${7:-}"
  local turns_used="${8:-0}"

  if [[ -z "$agent" || -z "$action" || -z "$task" || -z "$status" ]]; then
    echo "Usage: audit-log.sh log <project_root> <agent> <action> <task> <status> [file] [turns_used]" >&2
    exit 1
  fi

  # Validate file path stays within project
  if [[ -n "$file" ]]; then
    local real_file
    real_file=$(realpath "$PROJECT_ROOT/$file" 2>/dev/null || echo "")
    if [[ -n "$real_file" && "$real_file" != "$REAL_ROOT"/* ]]; then
      echo "Error: File path escapes project root: $file" >&2
      exit 1
    fi
  fi

  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Capture diff if a file was specified and it has uncommitted changes
  local diff=""
  if [[ -n "$file" && -f "$PROJECT_ROOT/$file" ]]; then
    diff=$(cd "$PROJECT_ROOT" && git diff -- "$file" 2>/dev/null || true)
    if [[ -z "$diff" ]]; then
      diff=$(cd "$PROJECT_ROOT" && git diff --cached -- "$file" 2>/dev/null || true)
    fi
  fi

  # Build JSON entry — pass all values via env vars to prevent injection
  ENTRY_TS="$ts" \
  ENTRY_AGENT="$agent" \
  ENTRY_ACTION="$action" \
  ENTRY_TASK="$task" \
  ENTRY_STATUS="$status" \
  ENTRY_TURNS="$turns_used" \
  ENTRY_FILE="$file" \
  ENTRY_DIFF="$diff" \
  python3 -c "
import json, os
entry = {
    'ts': os.environ['ENTRY_TS'],
    'agent': os.environ['ENTRY_AGENT'],
    'action': os.environ['ENTRY_ACTION'],
    'task': os.environ['ENTRY_TASK'],
    'status': os.environ['ENTRY_STATUS'],
    'turns_used': int(os.environ.get('ENTRY_TURNS') or '0')
}
f = os.environ.get('ENTRY_FILE', '')
if f:
    entry['file'] = f
d = os.environ.get('ENTRY_DIFF', '')
if d.strip():
    entry['diff'] = d
print(json.dumps(entry))
" >> "$LOG_FILE"

  echo "Logged: $agent/$action/$task -> $status" >&2
}

archive_logs() {
  mkdir -p "$ARCHIVE_DIR"

  local count=0
  for logfile in "$AUDIT_DIR"/*.jsonl; do
    [[ -f "$logfile" ]] || continue
    local basename
    basename=$(basename "$logfile")
    # Don't archive today's log
    if [[ "$basename" == "$TODAY.jsonl" ]]; then
      continue
    fi
    mv "$logfile" "$ARCHIVE_DIR/$basename"
    count=$((count + 1))
  done

  echo "Archived $count log file(s) to $ARCHIVE_DIR" >&2
}

prune_archive() {
  if [[ ! -d "$ARCHIVE_DIR" ]]; then
    echo "No archive directory found." >&2
    return
  fi

  local cutoff_ts
  cutoff_ts=$(date -u -v-30d +%Y-%m-%d 2>/dev/null || date -u -d '30 days ago' +%Y-%m-%d 2>/dev/null)

  local count=0
  for logfile in "$ARCHIVE_DIR"/*.jsonl; do
    [[ -f "$logfile" ]] || continue
    local basename
    basename=$(basename "$logfile" .jsonl)
    if [[ "$basename" < "$cutoff_ts" ]]; then
      rm "$logfile"
      count=$((count + 1))
    fi
  done

  echo "Pruned $count archived log file(s) older than 30 days." >&2
}

case "$COMMAND" in
  log)
    log_entry "$@"
    ;;
  archive)
    archive_logs
    ;;
  prune)
    prune_archive
    ;;
  *)
    echo "Unknown command: $COMMAND. Use: log, archive, prune" >&2
    exit 1
    ;;
esac
