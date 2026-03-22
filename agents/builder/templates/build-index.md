# Build Index
Project: [PROJECT_NAME]
Generated: [ISO TIMESTAMP]
Milestone: [MVP | V1 | V2 | partial]

---

## What Was Built

### Features Complete
[List each completed feature from user stories. One line per feature.]
- ✓ [Feature name] — [brief description of what's implemented]
- ✓ [Feature name]

### Features Incomplete (Parked)
- ⚠ [Feature name] — [why it's incomplete and what's missing]

---

## How to Run

### Prerequisites
- [Runtime version, e.g. Node.js 20+]
- [Any required tools]

### Setup
```bash
# 1. Install dependencies
[install command]

# 2. Configure environment
cp .env.example .env
# Fill in required values (see Environment Variables below)

# 3. Set up database (if applicable)
[migration command]

# 4. Start development server
[start command]
```

### Run Tests
```bash
[test command]
```

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| [VAR_NAME] | yes | [What it's for, where to get it] |
| [VAR_NAME] | yes | [What it's for] |
| [VAR_NAME] | no | [Optional, what it enables] |

---

## Key Files

| What | Path |
|------|------|
| Entry point | [src/...] |
| API routes | [src/...] |
| Database schema | [src/...] |
| Auth configuration | [src/...] |
| Environment config | [.env.example] |
| CI/CD pipeline | [.github/workflows/...] |

---

## Architecture Notes

Key decisions made during the build (from Architect handoff + Builder run):
- [Stack decision: e.g. "Next.js 14 with App Router, PostgreSQL via Prisma"]
- [Auth decision: e.g. "Google OAuth via NextAuth.js"]
- [Any deviations from original Architect spec, documented by mini-architect]

---

## Known Issues / Parked Tasks

[If none: "No known issues."]

- **[task-NNN]**: [description of what's missing/broken and how critical it is]

---

## Phase Branches

Git branches ready for Launcher to create PRs:
- `max-agents/phase-1` — [what this phase contains]
- `max-agents/phase-2` — [what this phase contains]
