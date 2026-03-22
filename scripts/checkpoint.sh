#!/bin/bash
# checkpoint.sh — Create and rollback git checkpoints per completed task
#
# Usage:
#   checkpoint.sh create <project_root> <task_id> [message]
#   checkpoint.sh rollback <project_root> <task_id>
#   checkpoint.sh list <project_root>
#
# Creates a git commit tagged with the task ID. Rollback restores to that point.

set -euo pipefail

COMMAND="${1:-}"
PROJECT_ROOT="${2:-}"

if [[ -z "$COMMAND" || -z "$PROJECT_ROOT" ]]; then
  echo "Usage: checkpoint.sh <create|rollback|list> <project_root> [args...]" >&2
  exit 1
fi

# Path containment check
REAL_ROOT=$(realpath "$PROJECT_ROOT" 2>/dev/null || echo "$PROJECT_ROOT")
ALLOWED_BASE="$HOME/Library/CloudStorage/Dropbox/ClaudeFolder"
if [[ "$REAL_ROOT" != "$ALLOWED_BASE"/* ]]; then
  echo "Error: Project root must be within ClaudeFolder" >&2
  exit 1
fi

STATE_FILE="$PROJECT_ROOT/.max-agents/state.json"

create_checkpoint() {
  local task_id="${3:-}"
  local message="${4:-}"

  if [[ -z "$task_id" ]]; then
    echo "Usage: checkpoint.sh create <project_root> <task_id> [message]" >&2
    exit 1
  fi

  # Sanitize task_id — alphanumeric, hyphens, underscores only
  if [[ ! "$task_id" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Invalid task_id (alphanumeric, hyphens, underscores only): $task_id" >&2
    exit 1
  fi

  cd "$PROJECT_ROOT"

  # Check if there are changes to commit
  if git diff --quiet && git diff --cached --quiet && [[ -z "$(git ls-files --others --exclude-standard)" ]]; then
    echo "No changes to checkpoint for $task_id" >&2
    return
  fi

  # Stage all changes, excluding secrets (respects .gitignore + explicit exclusions)
  git add -A -- ':!.env*' ':!secrets/'

  # Create commit
  local commit_msg="[max-agents] ${task_id}"
  if [[ -n "$message" ]]; then
    commit_msg="$commit_msg: $message"
  fi
  git commit -m "$commit_msg" --quiet

  # Tag with task ID for easy rollback
  local tag="max-agents/$task_id"
  git tag -f "$tag" HEAD

  # Get commit hash
  local commit_hash
  commit_hash=$(git rev-parse --short HEAD)

  # Update state.json checkpoints array — pass values via env vars
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  if [[ -f "$STATE_FILE" ]] && command -v python3 &>/dev/null; then
    CP_STATE_FILE="$STATE_FILE" \
    CP_TASK_ID="$task_id" \
    CP_COMMIT="$commit_hash" \
    CP_TAG="$tag" \
    CP_TS="$ts" \
    CP_MESSAGE="$message" \
    python3 -c "
import json, os
state_file = os.environ['CP_STATE_FILE']
with open(state_file, 'r') as f:
    state = json.load(f)
state.setdefault('checkpoints', []).append({
    'task_id': os.environ['CP_TASK_ID'],
    'commit': os.environ['CP_COMMIT'],
    'tag': os.environ['CP_TAG'],
    'timestamp': os.environ['CP_TS'],
    'message': os.environ['CP_MESSAGE']
})
with open(state_file, 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
  fi

  echo "Checkpoint created: $task_id ($commit_hash)" >&2
}

rollback_checkpoint() {
  local task_id="${3:-}"

  if [[ -z "$task_id" ]]; then
    echo "Usage: checkpoint.sh rollback <project_root> <task_id>" >&2
    exit 1
  fi

  # Sanitize task_id
  if [[ ! "$task_id" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Invalid task_id: $task_id" >&2
    exit 1
  fi

  cd "$PROJECT_ROOT"

  local tag="max-agents/$task_id"

  # Verify tag exists
  if ! git rev-parse "$tag" &>/dev/null; then
    echo "Error: No checkpoint found for $task_id (tag: $tag)" >&2
    exit 1
  fi

  # Check for uncommitted changes — stash them first
  if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
    echo "Stashing uncommitted changes before rollback..." >&2
    git stash push -m "pre-rollback safety stash $(date -u +%Y%m%d-%H%M%S)" || true
  fi

  # Show what we're rolling back to
  local target_hash
  target_hash=$(git rev-parse --short "$tag")
  local current_hash
  current_hash=$(git rev-parse --short HEAD)

  echo "Rolling back from $current_hash to $target_hash ($task_id)" >&2
  echo "Changes that will be undone:" >&2
  git log --oneline "$tag"..HEAD

  # Create a safety tag before rollback
  local safety_tag="max-agents/pre-rollback-$(date -u +%Y%m%d-%H%M%S)"
  git tag "$safety_tag" HEAD
  echo "Safety tag created: $safety_tag" >&2

  # Reset to the checkpoint
  git reset --hard "$tag"

  # Update state.json — remove checkpoints after the rollback point
  if [[ -f "$STATE_FILE" ]] && command -v python3 &>/dev/null; then
    CP_STATE_FILE="$STATE_FILE" \
    CP_TASK_ID="$task_id" \
    python3 -c "
import json, os
state_file = os.environ['CP_STATE_FILE']
target = os.environ['CP_TASK_ID']
with open(state_file, 'r') as f:
    state = json.load(f)
checkpoints = state.get('checkpoints', [])
kept = []
for cp in checkpoints:
    kept.append(cp)
    if cp.get('task_id') == target:
        break
state['checkpoints'] = kept
with open(state_file, 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
  fi

  echo "Rolled back to checkpoint: $task_id ($target_hash)" >&2
  echo "To undo this rollback: git reset --hard $safety_tag" >&2
  echo "To recover stashed changes: git stash pop" >&2
}

list_checkpoints() {
  cd "$PROJECT_ROOT"

  echo "=== Max-Agents Checkpoints ===" >&2

  local tags
  tags=$(git tag -l "max-agents/*" --sort=-creatordate 2>/dev/null || true)

  if [[ -z "$tags" ]]; then
    echo "No checkpoints found." >&2
    return
  fi

  while IFS= read -r tag; do
    # Skip pre-rollback safety tags in main listing
    if [[ "$tag" == *"pre-rollback"* ]]; then
      continue
    fi
    local hash
    hash=$(git rev-parse --short "$tag")
    local date
    date=$(git log -1 --format=%ci "$tag")
    local subject
    subject=$(git log -1 --format=%s "$tag")
    printf "  %-30s %s  %s  %s\n" "$tag" "$hash" "$date" "$subject"
  done <<< "$tags"
}

case "$COMMAND" in
  create)
    create_checkpoint "$@"
    ;;
  rollback)
    rollback_checkpoint "$@"
    ;;
  list)
    list_checkpoints
    ;;
  *)
    echo "Unknown command: $COMMAND. Use: create, rollback, list" >&2
    exit 1
    ;;
esac
