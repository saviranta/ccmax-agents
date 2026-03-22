#!/bin/bash
# report.sh — Report a bug or improvement idea to ccmax-agents from the terminal
#
# Usage:
#   report.sh "<title>"
#   report.sh "<title>" "<body>"
#   report.sh bug "<title>"
#   report.sh bug "<title>" "<body>"
#   report.sh improvement "<title>"
#   report.sh improvement "<title>" "<body>"
#
# Examples:
#   bash report.sh "Builder stalls when all remaining tasks depend on a parked task"
#   bash report.sh bug "Architect ignores stack choice and picks Next.js every time"
#   bash report.sh improvement "Researcher should save reports to project artifacts dir"
#   bash report.sh bug "validate.sh crashes on adopt mode" "Reproducible: run validate on a project with no handoffs dir"

set -euo pipefail

REPO="saviranta/ccmax-agents"

TYPES=("bug" "improvement" "question")

is_type() {
  local val="$1"
  for t in "${TYPES[@]}"; do [[ "$t" == "$val" ]] && return 0; done
  return 1
}

if [[ $# -eq 0 ]]; then
  echo "Usage: report.sh [bug|improvement|question] \"<title>\" [\"<body>\"]" >&2
  exit 1
fi

# Parse type (optional first arg)
TYPE=""
if is_type "${1:-}"; then
  TYPE="$1"
  shift
fi

TITLE="${1:-}"
BODY="${2:-}"

if [[ -z "$TITLE" ]]; then
  echo "Error: title is required." >&2
  exit 1
fi

# Build gh args
ARGS=(--repo "$REPO" --title "$TITLE")

if [[ -n "$TYPE" ]]; then
  ARGS+=(--label "$TYPE")
fi

if [[ -n "$BODY" ]]; then
  ARGS+=(--body "$BODY")
else
  ARGS+=(--body "")
fi

URL=$(gh issue create "${ARGS[@]}" 2>&1)
echo "$URL"
