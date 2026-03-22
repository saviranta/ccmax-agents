#!/bin/bash
# max-agents-init.sh — Initialize a new or existing project for agents-max
#
# Usage:
#   max-agents-init.sh
#
# Interactive script. Two modes:
#   1. New project — creates folder in ClaudeProjects/
#   2. Adopt existing project — scaffolds into existing folder

set -euo pipefail

# ─── Configuration ───

CLAUDE_FOLDER="$HOME/Library/CloudStorage/Dropbox/ClaudeFolder"
PROJECTS_DIR="$CLAUDE_FOLDER/ClaudeProjects"
AGENTS_MAX_DIR="$CLAUDE_FOLDER/agents-max"
TEMPLATES_DIR="$AGENTS_MAX_DIR/templates"
SCRIPTS_DIR="$AGENTS_MAX_DIR/scripts"

# ─── Helpers ───

prompt() {
  local var_name="$1"
  local message="$2"
  local default="${3:-}"

  if [[ -n "$default" ]]; then
    printf "%s [%s]: " "$message" "$default" >&2
  else
    printf "%s: " "$message" >&2
  fi

  local input
  read -r input

  if [[ -z "$input" && -n "$default" ]]; then
    printf -v "$var_name" '%s' "$default"
  else
    printf -v "$var_name" '%s' "$input"
  fi
}

to_kebab() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

# ─── Welcome ───

echo ""
echo "╔══════════════════════════════════════╗"
echo "║        agents-max  ·  init           ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ─── Mode selection ───

echo "What would you like to do?"
echo "  1) Create a new project"
echo "  2) Adopt an existing project"
echo ""
prompt MODE "Choose (1 or 2)"

case "$MODE" in
  1) MODE="new" ;;
  2) MODE="adopt" ;;
  *) echo "Invalid choice. Exiting." >&2; exit 1 ;;
esac

# ─── Gather project info ───

if [[ "$MODE" == "new" ]]; then
  echo ""
  prompt PROJECT_NAME "Project name (kebab-case)"
  PROJECT_NAME=$(to_kebab "$PROJECT_NAME")

  if [[ -z "$PROJECT_NAME" ]]; then
    echo "Project name cannot be empty." >&2
    exit 1
  fi

  PROJECT_ROOT="$PROJECTS_DIR/$PROJECT_NAME"

  if [[ -d "$PROJECT_ROOT" ]]; then
    echo "Error: Directory already exists: $PROJECT_ROOT" >&2
    echo "Use 'adopt' mode to add agents-max to an existing project." >&2
    exit 1
  fi

  prompt PROJECT_DESC "Brief project description"

  echo ""
  echo "Will create: $PROJECT_ROOT"

else
  echo ""
  prompt PROJECT_PATH "Path to existing project"

  # Expand ~ if present
  PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"

  if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "Error: Directory not found: $PROJECT_PATH" >&2
    exit 1
  fi

  # Path containment check
  REAL_PATH=$(realpath "$PROJECT_PATH" 2>/dev/null || echo "$PROJECT_PATH")
  if [[ "$REAL_PATH" != "$CLAUDE_FOLDER"/* ]]; then
    echo "Error: Project must be within ClaudeFolder" >&2
    exit 1
  fi

  PROJECT_ROOT="$PROJECT_PATH"
  PROJECT_NAME=$(basename "$PROJECT_ROOT")
  PROJECT_NAME=$(to_kebab "$PROJECT_NAME")

  prompt PROJECT_DESC "Brief project description"

  # Check if already initialized
  if [[ -d "$PROJECT_ROOT/.max-agents" ]]; then
    echo "Warning: .max-agents/ already exists in this project." >&2
    prompt OVERWRITE "Overwrite? (y/n)" "n"
    if [[ "$OVERWRITE" != "y" ]]; then
      echo "Aborted." >&2
      exit 0
    fi
  fi

  echo ""
  echo "Will adopt: $PROJECT_ROOT"
fi

# ─── Network domains ───

echo ""
echo "Network allowlist setup (agents can only reach these domains)."
echo "Defaults: github.com, npmjs.org, registry.yarnpkg.com"
echo ""

EXTRA_DOMAINS=""

prompt HAS_SUPABASE "Do you use Supabase? (y/n)" "n"
if [[ "$HAS_SUPABASE" == "y" ]]; then
  prompt SUPABASE_PROJECT "Supabase project ref (e.g., abcdef123456)"
  if [[ -n "$SUPABASE_PROJECT" ]]; then
    EXTRA_DOMAINS="${EXTRA_DOMAINS}${SUPABASE_PROJECT}.supabase.co,"
    EXTRA_DOMAINS="${EXTRA_DOMAINS}api.supabase.com,"
  fi
fi

prompt HAS_VERCEL "Do you use Vercel? (y/n)" "n"
if [[ "$HAS_VERCEL" == "y" ]]; then
  prompt VERCEL_PROJECT "Vercel project name (e.g., my-app)"
  if [[ -n "$VERCEL_PROJECT" ]]; then
    EXTRA_DOMAINS="${EXTRA_DOMAINS}${VERCEL_PROJECT}.vercel.app,"
    EXTRA_DOMAINS="${EXTRA_DOMAINS}vercel.com,api.vercel.com,"
  fi
fi

prompt HAS_OTHER "Any other domains agents need to reach? (comma-separated, or empty)"
if [[ -n "$HAS_OTHER" ]]; then
  EXTRA_DOMAINS="${EXTRA_DOMAINS}${HAS_OTHER},"
fi

# Remove trailing comma
EXTRA_DOMAINS="${EXTRA_DOMAINS%,}"

echo ""
prompt CONFIRM "Proceed? (y/n)" "y"
if [[ "$CONFIRM" != "y" ]]; then
  echo "Aborted." >&2
  exit 0
fi

# ─── Create directories ───

echo ""
echo "Creating directory structure..."

if [[ "$MODE" == "new" ]]; then
  mkdir -p "$PROJECT_ROOT"
fi

mkdir -p "$PROJECT_ROOT/.max-agents"/{artifacts/{prototyper,architect,builder,launcher,researcher,baseline},handoffs,audit-log/archive,checkpoints}
mkdir -p "$PROJECT_ROOT/.claude"

echo "  Created .max-agents/ directory tree"

# ─── Generate config.json ───

echo "Generating config.json..."

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

INIT_TEMPLATE="$TEMPLATES_DIR/config.json" \
INIT_NAME="$PROJECT_NAME" \
INIT_DESC="$PROJECT_DESC" \
INIT_ROOT="$PROJECT_ROOT" \
INIT_TOOLKIT="$AGENTS_MAX_DIR" \
INIT_TS="$TS" \
INIT_MODE="$MODE" \
INIT_EXTRA_DOMAINS="$EXTRA_DOMAINS" \
INIT_OUTPUT="$PROJECT_ROOT/.max-agents/config.json" \
python3 -c "
import json, os

config = json.load(open(os.environ['INIT_TEMPLATE']))
config['project_name'] = os.environ['INIT_NAME']
config['project_description'] = os.environ['INIT_DESC']
config['project_root'] = os.environ['INIT_ROOT']
config['toolkit_root'] = os.environ['INIT_TOOLKIT']
config['created_at'] = os.environ['INIT_TS']
config['mode'] = os.environ['INIT_MODE']

# Add extra domains
extra = os.environ.get('INIT_EXTRA_DOMAINS', '')
if extra:
    existing = config.get('security', {}).get('allowed_network_domains', [])
    for d in extra.split(','):
        d = d.strip()
        if d and d not in existing:
            existing.append(d)
    config['security']['allowed_network_domains'] = existing

with open(os.environ['INIT_OUTPUT'], 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
"

echo "  Generated .max-agents/config.json"

# ─── Generate state.json ───

echo "Generating state.json..."
cp "$TEMPLATES_DIR/state.json" "$PROJECT_ROOT/.max-agents/state.json"
echo "  Generated .max-agents/state.json"

# ─── Generate .claude/settings.json ───

if [[ -f "$PROJECT_ROOT/.claude/settings.json" ]]; then
  echo "  .claude/settings.json already exists — skipping (review manually)"
else
  echo "Generating .claude/settings.json..."

  # Generate settings with project-specific network allowlist
  INIT_TEMPLATE="$TEMPLATES_DIR/settings.json" \
  INIT_EXTRA_DOMAINS="$EXTRA_DOMAINS" \
  INIT_OUTPUT="$PROJECT_ROOT/.claude/settings.json" \
  python3 -c "
import json, os

settings = json.load(open(os.environ['INIT_TEMPLATE']))

# Replace broad wildcards with project-specific domains
domains = [
    'github.com',
    '*.github.com',
    '*.npmjs.org',
    'registry.yarnpkg.com'
]

extra = os.environ.get('INIT_EXTRA_DOMAINS', '')
if extra:
    for d in extra.split(','):
        d = d.strip()
        if d and d not in domains:
            domains.append(d)

settings['sandbox']['network']['allowedDomains'] = domains

with open(os.environ['INIT_OUTPUT'], 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
"

  echo "  Generated .claude/settings.json"
fi

# ─── Generate .claude/CLAUDE.md ───

if [[ -f "$PROJECT_ROOT/.claude/CLAUDE.md" ]]; then
  echo "  .claude/CLAUDE.md already exists — skipping"
else
  echo "Generating .claude/CLAUDE.md..."
  cat > "$PROJECT_ROOT/.claude/CLAUDE.md" << 'CLAUDEMD'
# Project Context

## agents-max

This project is managed by the agents-max system.

- Project state: `.max-agents/state.json`
- Configuration: `.max-agents/config.json`
- Artifacts: `.max-agents/artifacts/`
- Handoffs: `.max-agents/handoffs/`
- Audit log: `.max-agents/audit-log/`

### Agent Rules

- Always read `.max-agents/config.json` at session start
- Log all file modifications to the audit log
- Create a checkpoint after completing each task
- Never modify `.claude/settings.json`
- Never read or write `.env*` or `secrets/`
- Stay within this project directory
CLAUDEMD
  echo "  Generated .claude/CLAUDE.md"
fi

# ─── Generate .gitignore ───

GITIGNORE="$PROJECT_ROOT/.gitignore"

if [[ -f "$GITIGNORE" ]]; then
  if ! grep -q '.max-agents/' "$GITIGNORE" 2>/dev/null; then
    echo "" >> "$GITIGNORE"
    echo "# agents-max working data" >> "$GITIGNORE"
    echo ".max-agents/" >> "$GITIGNORE"
    echo "  Updated .gitignore"
  else
    echo "  .gitignore already includes .max-agents/"
  fi
else
  cat > "$GITIGNORE" << 'GITIGNORE'
# agents-max working data
.max-agents/

# Environment
.env
.env.*
.env.local

# Dependencies
node_modules/

# Build
dist/
build/
.next/

# OS
.DS_Store
Thumbs.db
GITIGNORE
  echo "  Generated .gitignore"
fi

# ─── Baseline snapshot (adopt mode only) ───

if [[ "$MODE" == "adopt" ]]; then
  echo ""
  echo "Creating baseline snapshot..."

  BASELINE_DIR="$PROJECT_ROOT/.max-agents/artifacts/baseline"

  # Project structure (top 3 levels, excluding hidden dirs and node_modules)
  find "$PROJECT_ROOT" -maxdepth 3 \
    -not -path '*/\.*' \
    -not -path '*/node_modules/*' \
    -not -path '*/.max-agents/*' \
    2>/dev/null | sed "s|$PROJECT_ROOT/||" | sort > "$BASELINE_DIR/structure.txt"
  echo "  Captured project structure"

  # Package dependencies
  for dep_file in package.json requirements.txt pyproject.toml Cargo.toml; do
    if [[ -f "$PROJECT_ROOT/$dep_file" ]]; then
      cp "$PROJECT_ROOT/$dep_file" "$BASELINE_DIR/$dep_file"
      echo "  Captured $dep_file"
    fi
  done

  # Git info if available
  if [[ -d "$PROJECT_ROOT/.git" ]]; then
    (cd "$PROJECT_ROOT" && git log --oneline -20 > "$BASELINE_DIR/recent-commits.txt" 2>/dev/null || true)
    (cd "$PROJECT_ROOT" && git remote -v > "$BASELINE_DIR/git-remotes.txt" 2>/dev/null || true)
    (cd "$PROJECT_ROOT" && git branch -a > "$BASELINE_DIR/git-branches.txt" 2>/dev/null || true)
    echo "  Captured git info"
  fi

  # Summary — pass paths via env vars
  INIT_TS="$TS" \
  INIT_ROOT="$PROJECT_ROOT" \
  INIT_BASELINE="$BASELINE_DIR" \
  python3 -c "
import json, os

baseline_dir = os.environ['INIT_BASELINE']
project_root = os.environ['INIT_ROOT']

summary = {
    'snapshot_date': os.environ['INIT_TS'],
    'project_root': project_root,
    'files_captured': os.listdir(baseline_dir),
    'has_git': os.path.isdir(os.path.join(project_root, '.git')),
    'has_package_json': os.path.isfile(os.path.join(project_root, 'package.json')),
    'has_python': os.path.isfile(os.path.join(project_root, 'requirements.txt')) or os.path.isfile(os.path.join(project_root, 'pyproject.toml')),
    'has_rust': os.path.isfile(os.path.join(project_root, 'Cargo.toml'))
}

with open(os.path.join(baseline_dir, 'summary.json'), 'w') as f:
    json.dump(summary, f, indent=2)
    f.write('\n')
"
  echo "  Generated baseline summary"
fi

# ─── Done ───

echo ""
echo "╔══════════════════════════════════════╗"
echo "║            Setup complete            ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  Project:  $PROJECT_NAME"
echo "  Location: $PROJECT_ROOT"
echo "  Mode:     $MODE"
echo ""
echo "Next steps:"
echo "  1. cd $PROJECT_ROOT"
echo "  2. Review .claude/settings.json (security)"
echo "  3. Start an agent (Prototyper, Researcher, etc.)"
echo ""
echo "Validate setup:"
echo "  $SCRIPTS_DIR/validate.sh $PROJECT_ROOT"
echo ""
