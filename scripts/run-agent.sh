#!/bin/bash
# run-agent.sh — Launch an agents-max agent in a dedicated Claude Code session
#
# Usage:
#   bash run-agent.sh <agent-name> [project-path]
#
# Examples:
#   bash run-agent.sh prototyper              # uses current directory
#   bash run-agent.sh architect /path/to/project
#   bash run-agent.sh researcher              # no project needed

set -euo pipefail

AGENTS_MAX_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENTS_DIR="$AGENTS_MAX_DIR/agents"

# ─── Agent → model mapping ───

declare -A AGENT_MODELS
AGENT_MODELS=(
  [researcher]="opus"
  [prototyper]="opus"
  [architect]="opus"
  [builder]="opus"
  [launcher]="sonnet"
)

# ─── Validate input ───

if [[ $# -lt 1 ]]; then
  echo "Usage: bash run-agent.sh <agent-name> [project-path]"
  echo ""
  echo "Available agents:"
  for agent in researcher prototyper architect builder launcher; do
    echo "  $agent"
  done
  exit 1
fi

AGENT_NAME="$1"
PROJECT_PATH="${2:-.}"

# Resolve project path
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

# Validate agent exists
AGENT_FILE="$AGENTS_DIR/$AGENT_NAME/CLAUDE.md"
if [[ ! -f "$AGENT_FILE" ]]; then
  echo "Error: Unknown agent '$AGENT_NAME'" >&2
  echo "" >&2
  echo "Available agents:" >&2
  for agent in researcher prototyper architect builder launcher; do
    echo "  $agent" >&2
  done
  exit 1
fi

# Validate project is initialized (skip for researcher — it works anywhere)
if [[ "$AGENT_NAME" != "researcher" && ! -d "$PROJECT_PATH/.max-agents" ]]; then
  echo "Error: Project not initialized. No .max-agents/ directory found at $PROJECT_PATH" >&2
  echo "" >&2
  echo "Run the init script first:" >&2
  echo "  bash $AGENTS_MAX_DIR/scripts/max-agents-init.sh" >&2
  exit 1
fi

# ─── Launch ───

MODEL="${AGENT_MODELS[$AGENT_NAME]}"

echo "Launching $AGENT_NAME agent (model: $MODEL)"
echo "Project:  $PROJECT_PATH"
echo ""

cd "$PROJECT_PATH"
exec claude --append-system-prompt "$(cat "$AGENT_FILE")" --model "$MODEL"
