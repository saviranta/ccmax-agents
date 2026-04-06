#!/bin/bash
# metrics.sh — Cross-agent metrics aggregation for the agents-max pipeline
#
# Usage:
#   metrics.sh <project_root> [--format json|markdown|both] [--since YYYY-MM-DD]

set -euo pipefail

# Arguments
PROJECT_ROOT="${1:-}"

if [[ -z "$PROJECT_ROOT" ]]; then
  echo "Usage: metrics.sh <project_root> [--format json|markdown|both] [--since YYYY-MM-DD]" >&2
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

# Shift to process optional flags
shift 1 || true
FORMAT="both"
SINCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format) FORMAT="${2:-both}"; shift 2 ;;
    --since)  SINCE="${2:-}"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Paths
AUDIT_DIR="$REAL_ROOT/.max-agents/audit-log"
TG_PATH="$REAL_ROOT/.max-agents/artifacts/architect/task-graph.json"
METRICS_DIR="$REAL_ROOT/.max-agents/artifacts/metrics"
TODAY=$(date -u +%Y-%m-%d)

mkdir -p "$METRICS_DIR"

echo "Computing metrics for: $REAL_ROOT" >&2
echo "Format: $FORMAT | Since: ${SINCE:-all time}" >&2

# ── Python3 block: compute all metrics, emit JSON ─────────────────────────────

METRICS_JSON=$(
  METRICS_AUDIT_DIR="$AUDIT_DIR" \
  METRICS_TG_PATH="$TG_PATH" \
  METRICS_SINCE="$SINCE" \
  METRICS_DATE="$TODAY" \
  python3 -c "
import json
import os
import glob
import statistics
from datetime import datetime, timezone

audit_dir  = os.environ['METRICS_AUDIT_DIR']
tg_path    = os.environ['METRICS_TG_PATH']
since_str  = os.environ['METRICS_SINCE']
today      = os.environ['METRICS_DATE']

# ── helpers ───────────────────────────────────────────────────────────────────

def load_json(path):
    try:
        with open(path, 'r') as f:
            return json.load(f)
    except Exception:
        return {}

def load_audit_entries(audit_dir, since_str):
    entries = []
    patterns = [
        os.path.join(audit_dir, '*.jsonl'),
        os.path.join(audit_dir, 'archive', '*.jsonl'),
    ]
    for pattern in patterns:
        for path in glob.glob(pattern):
            try:
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
    if since_str:
        entries = [e for e in entries if e.get('ts', '') >= since_str]
    return entries

def safe_mean(lst):
    return statistics.mean(lst) if lst else 0

def safe_median(lst):
    return statistics.median(lst) if lst else 0

# ── load data ─────────────────────────────────────────────────────────────────

entries = load_audit_entries(audit_dir, since_str)
task_graph = load_json(tg_path)
tasks_list = task_graph.get('tasks', [])

now_ts = datetime.now(timezone.utc).isoformat()
period_label = since_str if since_str else 'all time'

# ── 1. tasks_by_builder ───────────────────────────────────────────────────────

STATUS_DISPLAY = {
    'done': 'completed',
    'parked': 'parked',
    'failed': 'failed',
    'pending': 'pending',
    'in_progress': 'in_progress',
    'blocked': 'blocked',
}
ALL_STATUSES = list(STATUS_DISPLAY.keys())

tasks_by_builder = {}
for t in tasks_list:
    builder = t.get('assigned_to') or 'unassigned'
    status  = t.get('status', 'pending')
    if builder not in tasks_by_builder:
        tasks_by_builder[builder] = {STATUS_DISPLAY.get(s, s): 0 for s in ALL_STATUSES}
    display = STATUS_DISPLAY.get(status, status)
    tasks_by_builder[builder][display] = tasks_by_builder[builder].get(display, 0) + 1

# ── 2. review_pass_rate ───────────────────────────────────────────────────────

review_entries = [
    e for e in entries
    if 'review' in e.get('action', '').lower() or 'convention' in e.get('action', '').lower()
]

task_reviews = {}
for e in review_entries:
    tid = e.get('task', '') or e.get('task_id', '')
    if not tid:
        continue
    if tid not in task_reviews:
        task_reviews[tid] = []
    task_reviews[tid].append(e)

total_reviewed = len(task_reviews)
first_pass     = 0
after_fix      = 0
never_passed   = 0

for tid, revs in task_reviews.items():
    statuses = [r.get('status', '') for r in revs]
    passed = [s in ('success', 'pass', 'passed', 'ok') for s in statuses]
    if not any(passed):
        never_passed += 1
    elif passed[0]:
        first_pass += 1
    else:
        after_fix += 1

def rate(n, total):
    return round(n / total, 4) if total else 0.0

review_pass_rate = {
    'total_reviewed': total_reviewed,
    'first_pass': first_pass,
    'first_pass_rate': rate(first_pass, total_reviewed),
    'after_fix': after_fix,
    'after_fix_rate': rate(after_fix, total_reviewed),
    'never_passed': never_passed,
}

# ── 3. turns_by_size ──────────────────────────────────────────────────────────

task_turns_map = {}
for e in entries:
    tid   = e.get('task', '') or e.get('task_id', '')
    turns = e.get('turns_used', 0) or 0
    if tid:
        task_turns_map[tid] = task_turns_map.get(tid, 0) + turns

size_groups = {}
for t in tasks_list:
    tid  = t.get('id', '')
    size = t.get('size', 'unknown')
    turns = task_turns_map.get(tid, 0)
    if size not in size_groups:
        size_groups[size] = []
    size_groups[size].append(turns)

turns_by_size = {}
for size, turn_list in size_groups.items():
    turns_by_size[size] = {
        'count':  len(turn_list),
        'avg':    round(safe_mean(turn_list), 2),
        'median': round(safe_median(turn_list), 2),
        'max':    max(turn_list) if turn_list else 0,
    }

# ── 4. stalls ─────────────────────────────────────────────────────────────────

stall_actions = ('task-parked', 'task-failed')
stall_entries = [e for e in entries if e.get('action', '') in stall_actions]
stall_causes = {}
for e in stall_entries:
    action = e.get('action', 'unknown')
    stall_causes[action] = stall_causes.get(action, 0) + 1

stalls = {
    'total': len(stall_entries),
    'causes': stall_causes,
}

# ── 5. phase_completion ───────────────────────────────────────────────────────

phase_entries = [e for e in entries if e.get('action', '') == 'phase-complete']
phase_completion = {}
for e in phase_entries:
    tid = e.get('task', '') or e.get('task_id', '') or e.get('phase', '')
    ts  = e.get('ts', '')
    if tid:
        phase_completion[tid] = ts

# ── 6. turns_by_agent ─────────────────────────────────────────────────────────

agent_turns = {}
for e in entries:
    ag    = e.get('agent', 'unknown') or 'unknown'
    turns = e.get('turns_used', 0) or 0
    agent_turns[ag] = agent_turns.get(ag, 0) + turns

turns_by_agent = {
    'data': agent_turns,
    'note': 'turns are a proxy for resource usage; token counts not available in audit log',
}

# ── 7. task_summary ───────────────────────────────────────────────────────────

status_counts = {}
for t in tasks_list:
    s = t.get('status', 'pending')
    status_counts[s] = status_counts.get(s, 0) + 1

task_summary = {
    'total': len(tasks_list),
    'by_status': status_counts,
}

# ── assemble output ───────────────────────────────────────────────────────────

output = {
    'generated_at': now_ts,
    'period': period_label,
    'entries_analyzed': len(entries),
    'task_summary': task_summary,
    'tasks_by_builder': tasks_by_builder,
    'review_pass_rate': review_pass_rate,
    'turns_by_size': turns_by_size,
    'stalls': stalls,
    'phase_completion': phase_completion,
    'turns_by_agent': turns_by_agent,
}

print(json.dumps(output, indent=2))
"
)

# ── Write JSON output ─────────────────────────────────────────────────────────

JSON_OUT="$METRICS_DIR/metrics-$TODAY.json"
printf '%s\n' "$METRICS_JSON" > "$JSON_OUT"
cp "$JSON_OUT" "$METRICS_DIR/latest.json"
echo "Written: $JSON_OUT" >&2

# ── Python3 block: render markdown ───────────────────────────────────────────

if [[ "$FORMAT" == "markdown" || "$FORMAT" == "both" ]]; then
  MD_OUT="$METRICS_DIR/metrics-$TODAY.md"

  METRICS_JSON="$METRICS_JSON" \
  python3 -c "
import json
import os
from datetime import datetime, timezone

raw  = os.environ['METRICS_JSON']
data = json.loads(raw)

generated_at     = data.get('generated_at', '')
period           = data.get('period', 'all time')
entries_analyzed = data.get('entries_analyzed', 0)
task_summary     = data.get('task_summary', {})
tasks_by_builder = data.get('tasks_by_builder', {})
review           = data.get('review_pass_rate', {})
turns_by_size    = data.get('turns_by_size', {})
stalls           = data.get('stalls', {})
phase_completion = data.get('phase_completion', {})
turns_by_agent   = data.get('turns_by_agent', {})

lines = []

def h(n, text):
    lines.append('#' * n + ' ' + text)

def blank():
    lines.append('')

def row(*cells):
    lines.append('| ' + ' | '.join(str(c) for c in cells) + ' |')

def sep(*widths):
    lines.append('| ' + ' | '.join('-' * (w or 3) for w in widths) + ' |')

def pct(n, total):
    if not total:
        return '—'
    return f'{round(n / total * 100, 1)}%'

# ── Header ────────────────────────────────────────────────────────────────────

h(1, 'agents-max Metrics Report')
blank()
lines.append(f'Generated: {generated_at} | Period: {period} to now | Entries analyzed: {entries_analyzed}')
blank()

# ── Summary ───────────────────────────────────────────────────────────────────

h(2, 'Summary')
blank()
row('Metric', 'Value')
sep(30, 10)
row('Total tasks', task_summary.get('total', 0))
row('Entries analyzed', entries_analyzed)
row('Period', period)
row('Total stalls', stalls.get('total', 0))
row('Tasks reviewed', review.get('total_reviewed', 0))
row('First-pass rate', pct(review.get('first_pass', 0), review.get('total_reviewed', 0)))
blank()

# ── Tasks by Builder ──────────────────────────────────────────────────────────

h(2, 'Tasks by Builder')
blank()
row('Builder', 'Completed', 'Parked', 'Failed', 'Pending', 'In Progress', 'Blocked')
sep(24, 10, 8, 8, 9, 12, 9)
for builder, counts in sorted(tasks_by_builder.items()):
    row(
        builder,
        counts.get('completed', 0),
        counts.get('parked', 0),
        counts.get('failed', 0),
        counts.get('pending', 0),
        counts.get('in_progress', 0),
        counts.get('blocked', 0),
    )
blank()

# ── Review Pass Rate ──────────────────────────────────────────────────────────

h(2, 'Review Pass Rate')
blank()
row('Metric', 'Count', 'Rate')
sep(24, 8, 8)
total_rev = review.get('total_reviewed', 0)
row('Total reviewed',  total_rev, '—')
row('First-pass',      review.get('first_pass', 0),  pct(review.get('first_pass', 0),  total_rev))
row('Passed after fix', review.get('after_fix', 0),  pct(review.get('after_fix', 0),   total_rev))
row('Never passed',    review.get('never_passed', 0), pct(review.get('never_passed', 0), total_rev))
blank()

# ── Turns per Task by Size ────────────────────────────────────────────────────

h(2, 'Turns per Task by Size')
blank()
row('Size', 'Tasks', 'Avg Turns', 'Median', 'Max')
sep(8, 7, 10, 8, 6)
for size in sorted(turns_by_size.keys()):
    s = turns_by_size[size]
    row(size, s.get('count', 0), s.get('avg', 0), s.get('median', 0), s.get('max', 0))
blank()

# ── Stalls ────────────────────────────────────────────────────────────────────

h(2, 'Stalls')
blank()
row('Cause', 'Count')
sep(20, 7)
causes = stalls.get('causes', {})
for cause, count in sorted(causes.items(), key=lambda x: -x[1]):
    row(cause, count)
if not causes:
    row('(none)', 0)
blank()
lines.append(f'**Total stalls:** {stalls.get(\"total\", 0)}')
blank()

# ── Turns by Agent ────────────────────────────────────────────────────────────

h(2, 'Turns by Agent')
blank()
agent_data = turns_by_agent.get('data', {})
row('Agent', 'Total Turns')
sep(24, 12)
for agent, turns in sorted(agent_data.items(), key=lambda x: -x[1]):
    row(agent, turns)
if not agent_data:
    row('(none)', 0)
blank()
lines.append(f'*Note: {turns_by_agent.get(\"note\", \"\")}*')
blank()

# ── Phase Completion ──────────────────────────────────────────────────────────

h(2, 'Phase Completion')
blank()
if phase_completion:
    row('Phase / Task', 'Completed At')
    sep(28, 26)
    for phase_id, ts in sorted(phase_completion.items(), key=lambda x: x[1]):
        row(phase_id, ts)
else:
    lines.append('No phase-complete entries recorded yet.')
blank()

print('\n'.join(lines))
" > "$MD_OUT"

  echo "Written: $MD_OUT" >&2
fi

echo "" >&2
echo "Metrics written to: $METRICS_DIR" >&2
