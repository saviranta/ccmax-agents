#!/bin/bash
# dashboard.sh — Terminal dashboard for the agents-max pipeline system
#
# Usage:
#   dashboard.sh <project_path>

set -euo pipefail

PROJECT_ROOT="${1:-}"

if [[ -z "$PROJECT_ROOT" ]]; then
  echo "Usage: dashboard.sh <project_path>" >&2
  exit 1
fi

# Path containment check
AGENTS_MAX_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REAL_ROOT=$(realpath "$PROJECT_ROOT" 2>/dev/null || echo "$PROJECT_ROOT")
ALLOWED_BASE="${AGENTS_MAX_BASE:-$(dirname "$AGENTS_MAX_DIR")}"
if [[ "$REAL_ROOT" != "$ALLOWED_BASE"/* ]]; then
  echo "Error: Project root must be within ClaudeFolder" >&2
  exit 1
fi

VIEW=1

while true; do
  clear

  PROJECT_ROOT="$REAL_ROOT" VIEW="$VIEW" python3 <<PYEOF
import json
import os
import sys
import glob
from datetime import datetime, timezone

PROJECT_ROOT = os.environ['PROJECT_ROOT']
VIEW = int(os.environ['VIEW'])

# ── helpers ──────────────────────────────────────────────────────────────────

def load_json(path):
    try:
        with open(path, 'r') as f:
            return json.load(f)
    except Exception:
        return {}

def load_audit_logs(audit_dir):
    entries = []
    try:
        for path in glob.glob(os.path.join(audit_dir, '*.jsonl')):
            with open(path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entries.append(json.loads(line))
                    except Exception:
                        pass
    except Exception:
        pass
    entries.sort(key=lambda e: e.get('ts', ''))
    return entries

def detect_phase(handoffs_dir):
    try:
        files = os.listdir(handoffs_dir)
    except Exception:
        files = []
    if 'builder-to-launcher.json' in files:
        return 'Launching'
    if 'architect-to-builder.json' in files:
        return 'Building'
    if 'prototyper-to-architect.json' in files:
        return 'Architecting'
    return 'Prototyping'

def progress_bar(done, total, width=20):
    if total == 0:
        filled = 0
    else:
        filled = int(round(done / total * width))
    filled = max(0, min(filled, width))
    return '#' * filled + '.' * (width - filled)

def status_icon(status):
    icons = {
        'done': '✓',
        'in_progress': '▶',
        'pending': '·',
        'parked': '⊘',
        'failed': '✗',
        'blocked': '⏸',
    }
    return icons.get(status, '?')

def ago(iso_str):
    if not iso_str:
        return '—'
    try:
        ts = datetime.fromisoformat(iso_str.replace('Z', '+00:00'))
        now = datetime.now(timezone.utc)
        delta = int((now - ts).total_seconds())
        if delta < 0:
            delta = 0
        if delta < 60:
            return f'{delta}s ago'
        m, s = divmod(delta, 60)
        if m < 60:
            return f'{m}m {s}s ago'
        h, m = divmod(m, 60)
        if h < 24:
            return f'{h}h {m}m ago'
        d, h = divmod(h, 24)
        return f'{d}d {h}h ago'
    except Exception:
        return iso_str

def hms(iso_str):
    if not iso_str:
        return '—'
    try:
        ts = datetime.fromisoformat(iso_str.replace('Z', '+00:00'))
        return ts.strftime('%H:%M:%S')
    except Exception:
        return iso_str[:8] if len(iso_str) >= 8 else iso_str

def trunc(s, n):
    s = str(s) if s is not None else ''
    return s[:n] if len(s) <= n else s[:n-1] + '…'

def divider_heavy(label='', width=80):
    if label:
        left = ' ' + label + ' '
        bar = '═' * ((width - len(left)) // 2)
        line = bar + left + '═' * (width - len(bar) - len(left))
    else:
        line = '═' * width
    print(line[:width])

def divider_light(label='', width=80):
    if label:
        left = ' ' + label + ' '
        bar = '─' * 2
        rest = '─' * (width - len(bar) - len(left) - 1)
        line = bar + left + rest
    else:
        line = '─' * width
    print(line[:width])

# ── data loading ─────────────────────────────────────────────────────────────

max_dir     = os.path.join(PROJECT_ROOT, '.max-agents')
config      = load_json(os.path.join(max_dir, 'config.json'))
state       = load_json(os.path.join(max_dir, 'state.json'))
task_graph  = load_json(os.path.join(max_dir, 'artifacts', 'architect', 'task-graph.json'))
audit_dir   = os.path.join(max_dir, 'audit-log')
handoffs_dir = os.path.join(max_dir, 'handoffs')
audit       = load_audit_logs(audit_dir)

project_name = config.get('name', os.path.basename(PROJECT_ROOT))
now_str = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')

# ── view renderers ────────────────────────────────────────────────────────────

def render_view_1(config, state, audit, handoffs_dir):
    phase = detect_phase(handoffs_dir)
    project_name = config.get('name', os.path.basename(PROJECT_ROOT))
    header = f'  {project_name}  │  Phase: {phase}  │  {now_str}'
    divider_heavy(f'Running Now')
    print(header)
    divider_light()

    # Active agents
    active_agents = state.get('active_agents', [])
    divider_light('Active Agents')
    if not active_agents:
        print('  No active agents')
    else:
        print(f'  {"Agent":<22} {"Task":<24} {"Started":<16}')
        print(f'  {"─"*22} {"─"*24} {"─"*16}')
        for ag in active_agents:
            name    = trunc(ag.get('agent', ag.get('name', '?')), 22)
            task    = trunc(ag.get('task', ag.get('current_task', '—')), 24)
            started = ago(ag.get('started', ag.get('started_at', '')))
            print(f'  {name:<22} {task:<24} {started:<16}')

    divider_light()

    # Recent activity
    divider_light('Recent Activity  (last 10)')
    recent = audit[-10:][::-1]
    if not recent:
        print('  No audit log entries yet')
    else:
        print(f'  {"Time":<8} {"Agent":<18} {"Action":<12} {"Task":<20} {"Status":<10}')
        print(f'  {"─"*8} {"─"*18} {"─"*12} {"─"*20} {"─"*10}')
        for e in recent:
            t      = hms(e.get('ts', ''))
            agent  = trunc(e.get('agent', '?'), 18)
            action = trunc(e.get('action', '?'), 12)
            task   = trunc(e.get('task', '—'), 20)
            status = trunc(e.get('status', '—'), 10)
            print(f'  {t:<8} {agent:<18} {action:<12} {task:<20} {status:<10}')

def render_view_2(config, state, task_graph):
    project_name = config.get('name', os.path.basename(PROJECT_ROOT))
    divider_heavy('Task Graph')
    print(f'  {project_name}  │  {now_str}')
    divider_light()

    milestones = task_graph.get('milestones', ['mvp', 'v1', 'v2'])
    tasks_list = task_graph.get('tasks', [])

    # Milestone progress bars
    divider_light('Milestone Progress')
    for ms in milestones:
        ms_tasks = [t for t in tasks_list if t.get('milestone', '') == ms]
        total = len(ms_tasks)
        done  = sum(1 for t in ms_tasks if t.get('status', '') == 'done')
        pct   = int(done / total * 100) if total else 0
        bar   = progress_bar(done, total, 20)
        label = ms.upper()
        print(f'  [{bar}] {done}/{total} ({pct}%) — {label}')

    divider_light()

    # Phase breakdown
    phases = task_graph.get('phases', [])
    # Also collect phases from tasks if not explicitly listed
    if not phases:
        seen = {}
        for t in tasks_list:
            p = t.get('phase', '')
            ms = t.get('milestone', '')
            if p and p not in seen:
                seen[p] = ms
        phases = [{'id': k, 'milestone': v} for k, v in seen.items()]

    divider_light('Phases')
    if not phases:
        print('  No phase data')
    else:
        print(f'  {"Phase":<20} {"Milestone":<8} {"Tasks":>5}  {"✓":>4} {"▶":>4} {"·":>4} {"⊘":>4} {"✗":>4}')
        print(f'  {"─"*20} {"─"*8} {"─"*5}  {"─"*4} {"─"*4} {"─"*4} {"─"*4} {"─"*4}')
        for ph in phases:
            ph_id  = ph.get('id', ph.get('name', str(ph))) if isinstance(ph, dict) else str(ph)
            ms_id  = ph.get('milestone', '—') if isinstance(ph, dict) else '—'
            ph_tasks = [t for t in tasks_list if t.get('phase', '') == ph_id]
            total  = len(ph_tasks)
            done_c = sum(1 for t in ph_tasks if t.get('status') == 'done')
            inp_c  = sum(1 for t in ph_tasks if t.get('status') == 'in_progress')
            pend_c = sum(1 for t in ph_tasks if t.get('status') == 'pending')
            park_c = sum(1 for t in ph_tasks if t.get('status') == 'parked')
            fail_c = sum(1 for t in ph_tasks if t.get('status') == 'failed')
            print(f'  {trunc(ph_id,20):<20} {trunc(ms_id,8):<8} {total:>5}  {done_c:>4} {inp_c:>4} {pend_c:>4} {park_c:>4} {fail_c:>4}')

    divider_light()

    # Checkpoints
    checkpoints = state.get('checkpoints', [])[-8:]
    divider_light('Recent Checkpoints')
    if not checkpoints:
        print('  No checkpoints yet')
    else:
        print(f'  {"Task":<24} {"Commit":<10} {"When":<18}')
        print(f'  {"─"*24} {"─"*10} {"─"*18}')
        for cp in reversed(checkpoints):
            task_id = trunc(cp.get('task_id', '?'), 24)
            commit  = trunc(cp.get('commit', '?'), 10)
            when    = ago(cp.get('timestamp', ''))
            print(f'  {task_id:<24} {commit:<10} {when:<18}')

def render_view_3(config, audit, task_graph):
    project_name = config.get('name', os.path.basename(PROJECT_ROOT))
    divider_heavy('Metrics')
    print(f'  {project_name}  │  {now_str}')
    divider_light()

    tasks_list = task_graph.get('tasks', [])

    # Turns by agent
    divider_light('Turns by Agent')
    agent_turns = {}
    for e in audit:
        ag = e.get('agent', '?')
        turns = e.get('turns_used', 0) or 0
        agent_turns[ag] = agent_turns.get(ag, 0) + turns

    if not agent_turns:
        print('  No turn data yet')
    else:
        max_turns = max(agent_turns.values()) if agent_turns else 1
        bar_width = 20
        print(f'  {"Agent":<22} {"Turns":>6}  {"":^{bar_width}}')
        print(f'  {"─"*22} {"─"*6}  {"─"*bar_width}')
        for ag, turns in sorted(agent_turns.items(), key=lambda x: -x[1]):
            filled = int(turns / max_turns * bar_width) if max_turns else 0
            bar = '#' * filled + ' ' * (bar_width - filled)
            print(f'  {trunc(ag,22):<22} {turns:>6}  |{bar}|')

    divider_light()

    # Status summary
    divider_light('Task Status Summary')
    all_statuses = ['done', 'in_progress', 'pending', 'parked', 'failed', 'blocked']
    counts = {s: 0 for s in all_statuses}
    for t in tasks_list:
        s = t.get('status', 'pending')
        if s in counts:
            counts[s] += 1
        else:
            counts['pending'] += 1
    total = len(tasks_list)
    print(f'  Total tasks: {total}')
    for s in all_statuses:
        icon = status_icon(s)
        c = counts[s]
        print(f'  {icon} {s:<12} {c:>4}')

    divider_light()

    # Last 10 completed tasks
    divider_light('Last 10 Completed Tasks')
    completed = [e for e in audit if e.get('status') in ('done', 'success', 'complete')][-10:][::-1]
    if not completed:
        print('  No completed tasks in audit log')
    else:
        print(f'  {"Task":<24} {"Agent":<18} {"Turns":>5}')
        print(f'  {"─"*24} {"─"*18} {"─"*5}')
        for e in completed:
            task  = trunc(e.get('task', '—'), 24)
            agent = trunc(e.get('agent', '?'), 18)
            turns = e.get('turns_used', 0) or 0
            print(f'  {task:<24} {agent:<18} {turns:>5}')

def render_view_4(audit):
    divider_heavy('Audit Log')
    print(f'  {now_str}  │  Last 30 entries (newest first)')
    divider_light()
    recent = audit[-30:][::-1]
    if not recent:
        print('  No audit log entries')
    else:
        print(f'  {"Time":<8} {"Agent":<18} {"Action":<12} {"Task":<20} {"Status":<10} {"D":1}')
        print(f'  {"─"*8} {"─"*18} {"─"*12} {"─"*20} {"─"*10} {"─"*1}')
        for e in recent:
            t      = hms(e.get('ts', ''))
            agent  = trunc(e.get('agent', '?'), 18)
            action = trunc(e.get('action', '?'), 12)
            task   = trunc(e.get('task', '—'), 20)
            status = trunc(e.get('status', '—'), 10)
            diff   = '~' if e.get('diff') else ' '
            print(f'  {t:<8} {agent:<18} {action:<12} {task:<20} {status:<10} {diff}')

# ── dispatch ──────────────────────────────────────────────────────────────────

if VIEW == 1:
    render_view_1(config, state, audit, handoffs_dir)
elif VIEW == 2:
    render_view_2(config, state, task_graph)
elif VIEW == 3:
    render_view_3(config, audit, task_graph)
elif VIEW == 4:
    render_view_4(audit)
else:
    print(f'Unknown view: {VIEW}')
PYEOF

  # Footer
  printf '\n%s\n' '────────────────────────────────────────────────────────────────────────────────'
  printf '%s\n'   '[1] Running  [2] Tasks  [3] Metrics  [4] Audit  [q] Quit  │  Auto-refresh 5s'

  read -rsn1 -t 5 key || true
  case "$key" in
    1) VIEW=1 ;;
    2) VIEW=2 ;;
    3) VIEW=3 ;;
    4) VIEW=4 ;;
    q|Q) echo ""; exit 0 ;;
  esac
done
