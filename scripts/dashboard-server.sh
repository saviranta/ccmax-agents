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
ALLOWED_BASE="${AGENTS_MAX_BASE:-$(dirname "$AGENTS_MAX_DIR")}"
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
from datetime import datetime, timezone, timedelta

paths_env = os.environ["PROJECT_PATHS_ENV"]
snapshot_out = os.environ["SNAPSHOT_OUT"]

project_paths = [p for p in paths_env.split(":") if p]
now = datetime.now(timezone.utc)

SKIP_DIRS = {
    "node_modules", ".git", "__pycache__", ".next", "dist", "build",
    ".max-agents", "venv", ".venv", "env", ".env", "coverage", ".pytest_cache",
}
LOC_EXTENSIONS = {
    ".py": "Python", ".ts": "TypeScript", ".tsx": "TypeScript",
    ".js": "JavaScript", ".jsx": "JavaScript", ".css": "CSS", ".scss": "CSS",
    ".sql": "SQL", ".sh": "Shell", ".json": "JSON", ".yaml": "YAML", ".yml": "YAML",
    ".html": "HTML", ".md": "Markdown",
}

def count_loc(project_root):
    by_lang = {}
    for dirpath, dirnames, filenames in os.walk(project_root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")]
        for fname in filenames:
            ext = os.path.splitext(fname)[1].lower()
            lang = LOC_EXTENSIONS.get(ext)
            if not lang:
                continue
            fpath = os.path.join(dirpath, fname)
            try:
                with open(fpath, "r", errors="ignore") as f:
                    lines = sum(1 for _ in f)
                by_lang[lang] = by_lang.get(lang, 0) + lines
            except Exception:
                pass
    total = sum(by_lang.values())
    return {"total": total, "by_language": dict(sorted(by_lang.items(), key=lambda x: -x[1]))}

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
    handoffs_dir = os.path.join(max_dir, "handoffs")
    if os.path.exists(os.path.join(handoffs_dir, "builder-to-launcher.json")):
        return "Launching"
    if os.path.exists(os.path.join(handoffs_dir, "architect-to-builder.json")):
        return "Building"
    if os.path.exists(os.path.join(handoffs_dir, "prototyper-to-architect.json")):
        return "Architecting"
    return "Prototyping"

def read_handoffs(max_dir):
    handoff_names = [
        "prototyper-to-architect",
        "architect-to-builder",
        "builder-to-launcher",
    ]
    handoffs_dir = os.path.join(max_dir, "handoffs")
    handoffs = {}
    for name in handoff_names:
        path = os.path.join(handoffs_dir, f"{name}.json")
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
    if not os.path.exists(task_graph_path):
        task_graph_path = os.path.join(max_dir, "artifacts", "architect", "task-graph.json")
    task_graph = read_json(task_graph_path) if os.path.exists(task_graph_path) else {}

    audit_log = read_all_audit_logs(max_dir, 200)

    # Infer active agents from audit entries in the last 10 minutes
    cutoff = now - timedelta(minutes=10)
    agent_last_seen = {}
    for entry in audit_log:
        ts_str = entry.get("ts") or entry.get("timestamp")
        if not ts_str:
            continue
        try:
            ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
            agent = entry.get("agent")
            if agent and ts > cutoff:
                if agent not in agent_last_seen or ts > agent_last_seen[agent]["ts"]:
                    agent_last_seen[agent] = {
                        "agent": agent,
                        "task": entry.get("task") or entry.get("task_id") or "—",
                        "started_at": ts_str,
                        "ts": ts,
                    }
        except Exception:
            pass
    inferred_active = [
        {"agent": v["agent"], "task": v["task"], "started_at": v["started_at"]}
        for v in sorted(agent_last_seen.values(), key=lambda x: x["ts"], reverse=True)
    ]

    state = read_json(os.path.join(max_dir, "state.json"))
    # Prefer state.json active_agents if populated, else use inferred
    if not state.get("active_agents"):
        state["active_agents"] = inferred_active

    projects[project_name] = {
        "config": config,
        "state": state,
        "task_graph": task_graph,
        "audit_log": audit_log,
        "handoffs": read_handoffs(max_dir),
        "phase": detect_phase(max_dir),
        "loc": count_loc(project_path),
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
    generate_snapshot || echo "[dashboard] snapshot generation failed at $(date)" >&2
    sleep 5
  done
}

snapshot_loop &
SNAPSHOT_PID=$!

# ─── Watchdog: restart loop if it dies ───

watchdog_loop() {
  while true; do
    sleep 10
    if ! kill -0 "$SNAPSHOT_PID" 2>/dev/null; then
      echo "[dashboard] snapshot loop died — restarting at $(date)" >&2
      snapshot_loop &
      SNAPSHOT_PID=$!
    fi
  done
}

watchdog_loop &
WATCHDOG_PID=$!

# ─── Cleanup on exit ───

trap 'kill $SNAPSHOT_PID $WATCHDOG_PID 2>/dev/null; exit 0' SIGINT SIGTERM

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
