#!/bin/bash
# improvement.sh — Self-improvement mechanism for the agents-max pipeline
#
# Usage:
#   improvement.sh record <project_root> <severity> <category> <description>
#   improvement.sh propose <project_root> <entry-id> "<proposed-fix>"
#   improvement.sh apply <project_root> <entry-id>
#   improvement.sh review <project_root>
#   improvement.sh milestone-check <project_root>

set -euo pipefail

COMMAND="${1:-}"
PROJECT_ROOT="${2:-}"

if [[ -z "$COMMAND" || -z "$PROJECT_ROOT" ]]; then
  echo "Usage: improvement.sh <record|propose|apply|review|milestone-check> <project_root> [args...]" >&2
  exit 1
fi

# Path containment check
REAL_ROOT=$(realpath "$PROJECT_ROOT" 2>/dev/null || echo "$PROJECT_ROOT")
ALLOWED_BASE="$HOME/Library/CloudStorage/Dropbox/ClaudeFolder"
if [[ "$REAL_ROOT" != "$ALLOWED_BASE"/* ]]; then
  echo "Error: Project root must be within ClaudeFolder" >&2
  exit 1
fi

JOURNAL_PATH="$PROJECT_ROOT/.max-agents/artifacts/improvement-journal.md"
TROUBLESHOOTING_PATH="$PROJECT_ROOT/docs/troubleshooting.md"

record_entry() {
  local severity="${3:-}"
  local category="${4:-}"
  local description="${5:-}"

  if [[ -z "$severity" || -z "$category" || -z "$description" ]]; then
    echo "Usage: improvement.sh record <project_root> <severity> <category> <description>" >&2
    exit 1
  fi

  # Validate severity
  if [[ "$severity" != "critical" && "$severity" != "non-critical" ]]; then
    echo "Error: severity must be one of: critical, non-critical" >&2
    exit 1
  fi

  # Validate category
  if [[ "$category" != "workflow" && "$category" != "agent" && "$category" != "handoff" && "$category" != "task-spec" ]]; then
    echo "Error: category must be one of: workflow, agent, handoff, task-spec" >&2
    exit 1
  fi

  # Create journal directory and file if needed
  mkdir -p "$(dirname "$JOURNAL_PATH")"
  if [[ ! -f "$JOURNAL_PATH" ]]; then
    printf '# Improvement Journal\n' > "$JOURNAL_PATH"
  fi

  JOURNAL_PATH="$JOURNAL_PATH" \
  ENTRY_SEVERITY="$severity" \
  ENTRY_CATEGORY="$category" \
  ENTRY_DESCRIPTION="$description" \
  python3 -c "
import os, re
from datetime import datetime, timezone

journal_path = os.environ['JOURNAL_PATH']
severity = os.environ['ENTRY_SEVERITY']
category = os.environ['ENTRY_CATEGORY']
description = os.environ['ENTRY_DESCRIPTION']

with open(journal_path, 'r') as f:
    content = f.read()

ids = re.findall(r'## ENTRY-(\d+)', content)
next_n = max((int(i) for i in ids), default=0) + 1
entry_id = f'ENTRY-{next_n:03d}'

timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

entry = f'''
---

## {entry_id}
- **ID:** {entry_id}
- **Timestamp:** {timestamp}
- **Severity:** {severity}
- **Category:** {category}
- **Status:** open
- **Description:** {description}
- **Proposed Fix:** (none)
- **Applied:** no
- **Applied At:** (none)
'''

with open(journal_path, 'a') as f:
    f.write(entry)

print(entry_id)
import sys
print(f'Recorded: {entry_id} ({severity})', file=sys.stderr)
"
}

propose_fix() {
  local target_id="${3:-}"
  local proposed_fix="${4:-}"

  if [[ -z "$target_id" || -z "$proposed_fix" ]]; then
    echo "Usage: improvement.sh propose <project_root> <entry-id> \"<proposed-fix>\"" >&2
    exit 1
  fi

  if [[ ! -f "$JOURNAL_PATH" ]]; then
    echo "Error: Journal not found: $JOURNAL_PATH" >&2
    exit 1
  fi

  JOURNAL_PATH="$JOURNAL_PATH" \
  TARGET_ID="$target_id" \
  PROPOSED_FIX="$proposed_fix" \
  python3 -c "
import os, re, sys

journal_path = os.environ['JOURNAL_PATH']
target = os.environ['TARGET_ID']
fix = os.environ['PROPOSED_FIX']

with open(journal_path, 'r') as f:
    content = f.read()

pattern = rf'(## {re.escape(target)}.*?)(\n---|\Z)'
match = re.search(pattern, content, re.DOTALL)
if not match:
    print(f'Error: Entry {target} not found in journal', file=sys.stderr)
    sys.exit(1)

old_block = match.group(0)
new_block = old_block.replace('**Proposed Fix:** (none)', f'**Proposed Fix:** {fix}')
new_block = new_block.replace('**Status:** open', '**Status:** proposed')

content = content[:match.start()] + new_block + content[match.end():]

with open(journal_path, 'w') as f:
    f.write(content)

print(f'Proposed fix added to {target}', file=sys.stderr)
"
}

apply_fix() {
  local target_id="${3:-}"

  if [[ -z "$target_id" ]]; then
    echo "Usage: improvement.sh apply <project_root> <entry-id>" >&2
    exit 1
  fi

  if [[ ! -f "$JOURNAL_PATH" ]]; then
    echo "Error: Journal not found: $JOURNAL_PATH" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$TROUBLESHOOTING_PATH")"

  JOURNAL_PATH="$JOURNAL_PATH" \
  TARGET_ID="$target_id" \
  TROUBLESHOOTING_PATH="$TROUBLESHOOTING_PATH" \
  python3 -c "
import os, re, sys
from datetime import datetime, timezone

journal_path = os.environ['JOURNAL_PATH']
target = os.environ['TARGET_ID']
troubleshooting_path = os.environ['TROUBLESHOOTING_PATH']

with open(journal_path, 'r') as f:
    content = f.read()

pattern = rf'(## {re.escape(target)}.*?)(\n---|\Z)'
match = re.search(pattern, content, re.DOTALL)
if not match:
    print(f'Error: Entry {target} not found in journal', file=sys.stderr)
    sys.exit(1)

block = match.group(1)

def extract_field(text, field):
    m = re.search(rf'\*\*{re.escape(field)}:\*\* (.+)', text)
    return m.group(1).strip() if m else ''

proposed_fix = extract_field(block, 'Proposed Fix')
if proposed_fix == '(none)' or not proposed_fix:
    print(f'Error: Entry {target} has no proposed fix. Run propose first.', file=sys.stderr)
    sys.exit(1)

severity = extract_field(block, 'Severity')
category = extract_field(block, 'Category')
description = extract_field(block, 'Description')
timestamp = extract_field(block, 'Timestamp')

applied_at = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

old_block = match.group(0)
new_block = old_block.replace('**Status:** open', '**Status:** applied')
new_block = new_block.replace('**Status:** proposed', '**Status:** applied')
new_block = new_block.replace('**Applied:** no', '**Applied:** yes')
new_block = new_block.replace('**Applied At:** (none)', f'**Applied At:** {applied_at}')

content = content[:match.start()] + new_block + content[match.end():]

with open(journal_path, 'w') as f:
    f.write(content)

if not os.path.exists(troubleshooting_path):
    with open(troubleshooting_path, 'w') as f:
        f.write('# Troubleshooting Guide\n\n_Auto-generated from improvement journal. New entries appended automatically._\n')

ts_entry = f'''
---

### {target}: {description}
- **Category:** {category}
- **Severity:** {severity}
- **Applied:** {timestamp}

**Problem:** {description}

**Fix:** {proposed_fix}
'''

with open(troubleshooting_path, 'a') as f:
    f.write(ts_entry)

print(f'Applied: {target}', file=sys.stderr)
print(f'Troubleshooting guide updated: {troubleshooting_path}', file=sys.stderr)
"
}

review_entries() {
  if [[ ! -f "$JOURNAL_PATH" ]]; then
    echo "No improvement journal found." >&2
    exit 0
  fi

  JOURNAL_PATH="$JOURNAL_PATH" \
  python3 -c "
import os, re, sys

journal_path = os.environ['JOURNAL_PATH']

with open(journal_path, 'r') as f:
    content = f.read()

blocks = re.findall(r'## ENTRY-\d+.*?(?=\n---|$)', content, re.DOTALL)

pending = []
for block in blocks:
    def get_field(text, field):
        m = re.search(rf'\*\*{re.escape(field)}:\*\* (.+)', text)
        return m.group(1).strip() if m else ''

    entry_id = get_field(block, 'ID')
    severity = get_field(block, 'Severity')
    status = get_field(block, 'Status')
    category = get_field(block, 'Category')
    description = get_field(block, 'Description')

    if severity == 'non-critical' and status in ('open', 'proposed'):
        pending.append((entry_id, status, category, description))

if not pending:
    print('No pending non-critical entries.', file=sys.stderr)
else:
    print(f'{len(pending)} pending non-critical entries:', file=sys.stderr)
    for entry_id, status, category, description in pending:
        status_label = f'[{status.upper()}]'
        print(f'  {entry_id} {status_label:<11} [{category:<9}] {description}', file=sys.stderr)
"
}

milestone_check() {
  if [[ ! -f "$JOURNAL_PATH" ]]; then
    echo "No improvement journal found. OK to proceed." >&2
    exit 0
  fi

  JOURNAL_PATH="$JOURNAL_PATH" \
  python3 -c "
import os, re, sys

journal_path = os.environ['JOURNAL_PATH']

with open(journal_path, 'r') as f:
    content = f.read()

blocks = re.findall(r'## ENTRY-\d+.*?(?=\n---|$)', content, re.DOTALL)

unresolved = []
for block in blocks:
    def get_field(text, field):
        m = re.search(rf'\*\*{re.escape(field)}:\*\* (.+)', text)
        return m.group(1).strip() if m else ''

    entry_id = get_field(block, 'ID')
    severity = get_field(block, 'Severity')
    status = get_field(block, 'Status')
    description = get_field(block, 'Description')

    if severity == 'critical' and status in ('open', 'proposed'):
        unresolved.append((entry_id, status, description))

if not unresolved:
    print('No unresolved critical issues. OK to proceed.', file=sys.stderr)
    sys.exit(0)
else:
    print(f'WARNING: {len(unresolved)} unresolved critical issue(s):', file=sys.stderr)
    for entry_id, status, description in unresolved:
        print(f'  {entry_id} [{status.upper()}] {description}', file=sys.stderr)
    print('Resolve these before proceeding past milestone.', file=sys.stderr)
    sys.exit(1)
"
}

case "$COMMAND" in
  record)          record_entry "$@" ;;
  propose)         propose_fix "$@" ;;
  apply)           apply_fix "$@" ;;
  review)          review_entries ;;
  milestone-check) milestone_check ;;
  *)
    echo "Unknown command: $COMMAND. Use: record, propose, apply, review, milestone-check" >&2
    exit 1
    ;;
esac
