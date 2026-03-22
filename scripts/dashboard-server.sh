#!/bin/bash
# dashboard-server.sh — Serve the agents-max web dashboard
#
# Usage:
#   dashboard-server.sh /path/to/project1 [/path/to/project2 ...]
#
# Reads each project's .max-agents/ state every 5 seconds, writes a snapshot
# to dashboard/data/snapshot.json, and serves dashboard/ on port 8787.

set -euo pipefail

AGENTS_MAX_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ALLOWED_BASE="$HOME/Library/CloudStorage/Dropbox/ClaudeFolder"
DASHBOARD_DIR="$AGENTS_MAX_DIR/dashboard"
SNAPSHOT_FILE="$DASHBOARD_DIR/data/snapshot.json"
PORT=8787

# ─── Argument validation ───

if [[ $# -eq 0 ]]; then
  echo "Usage: dashboard-server.sh /path/to/project1 [/path/to/project2 ...]" >&2
  exit 1
fi

PROJECT_PATHS=()
for arg in "$@"; do
  REAL_PATH=$(realpath "$arg" 2>/dev/null || echo "$arg")
  if [[ "$REAL_PATH" != "$ALLOWED_BASE"/* ]]; then
    echo "Error: Project path must be within ClaudeFolder: $arg" >&2
    exit 1
  fi
  if [[ ! -d "$REAL_PATH/.max-agents" ]]; then
    echo "Error: No .max-agents/ directory found in: $REAL_PATH" >&2
    exit 1
  fi
  PROJECT_PATHS+=("$REAL_PATH")
done

# ─── Snapshot generation ───

generate_snapshot() {
  # Build a colon-separated list of project paths to pass via env
  local paths_list
  paths_list=$(printf '%s\n' "${PROJECT_PATHS[@]}" | paste -sd ':' -)

  PROJECT_PATHS_ENV="$paths_list" \
  SNAPSHOT_OUT="$SNAPSHOT_FILE" \
  python3 - <<'PYEOF'
import json
import os
import sys
import glob
from datetime import datetime, timezone

paths_env = os.environ["PROJECT_PATHS_ENV"]
snapshot_out = os.environ["SNAPSHOT_OUT"]

project_paths = [p for p in paths_env.split(":") if p]

def read_json(path):
    try:
        with open(path, "r") as f:
            return json.load(f)
    except Exception:
        return {}

def read_jsonl_last_n(path, n=200):
    """Read last n lines from a JSONL file, sorted by ts field."""
    entries = []
    try:
        with open(path, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entries.append(json.loads(line))
                except Exception:
                    pass
    except Exception:
        return []
    # Sort by ts field if present
    entries.sort(key=lambda e: e.get("ts", ""))
    return entries[-n:]

def read_all_audit_logs(max_dir, n=200):
    """Read all JSONL files in audit-log/, merge, sort, return last n."""
    audit_dir = os.path.join(max_dir, "audit-log")
    all_entries = []
    if not os.path.isdir(audit_dir):
        return []
    for jsonl_file in sorted(glob.glob(os.path.join(audit_dir, "*.jsonl"))):
        try:
            with open(jsonl_file, "r") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        all_entries.append(json.loads(line))
                    except Exception:
                        pass
        except Exception:
            pass
    all_entries.sort(key=lambda e: e.get("ts", ""))
    return all_entries[-n:]

def detect_phase(max_dir):
    if os.path.exists(os.path.join(max_dir, "builder-to-launcher.json")):
        return "Launching"
    if os.path.exists(os.path.join(max_dir, "architect-to-builder.json")):
        return "Building"
    if os.path.exists(os.path.join(max_dir, "prototyper-to-architect.json")):
        return "Architecting"
    return "Prototyping"

def read_handoffs(max_dir):
    handoff_names = [
        "prototyper-to-architect",
        "architect-to-builder",
        "builder-to-launcher",
    ]
    handoffs = {}
    for name in handoff_names:
        path = os.path.join(max_dir, f"{name}.json")
        if os.path.exists(path):
            handoffs[name] = read_json(path)
        else:
            handoffs[name] = {}
    return handoffs

projects = {}
for project_path in project_paths:
    max_dir = os.path.join(project_path, ".max-agents")
    config = read_json(os.path.join(max_dir, "config.json"))
    project_name = config.get("project_name") or os.path.basename(project_path)

    task_graph_path = os.path.join(max_dir, "task-graph.json")
    task_graph = read_json(task_graph_path) if os.path.exists(task_graph_path) else {}

    projects[project_name] = {
        "config": config,
        "state": read_json(os.path.join(max_dir, "state.json")),
        "task_graph": task_graph,
        "audit_log": read_all_audit_logs(max_dir, 200),
        "handoffs": read_handoffs(max_dir),
        "phase": detect_phase(max_dir),
    }

snapshot = {
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "projects": projects,
}

os.makedirs(os.path.dirname(snapshot_out), exist_ok=True)
with open(snapshot_out, "w") as f:
    json.dump(snapshot, f, indent=2)
PYEOF
}

# ─── Snapshot loop (background) ───

snapshot_loop() {
  while true; do
    generate_snapshot 2>/dev/null || true
    sleep 5
  done
}

snapshot_loop &
SNAPSHOT_PID=$!

# ─── Cleanup on exit ───

trap 'kill $SNAPSHOT_PID 2>/dev/null; exit 0' SIGINT SIGTERM

# ─── Start HTTP server ───

echo "agents-max dashboard: http://localhost:${PORT}/"
echo "Serving projects:"
for p in "${PROJECT_PATHS[@]}"; do
  echo "  $p"
done
echo ""
echo "Press Ctrl+C to stop."

cd "$DASHBOARD_DIR"
python3 -m http.server "$PORT"
