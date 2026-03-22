# Guide: What Makes a Good User Story

User stories are the contract between product intent and technical execution. A well-formed story tells the Builder exactly who benefits, what they need, and how success is measured — with no ambiguity left to interpret.

---

## Structure

Every user story requires the following elements.

### Actor Line

```
As a [actor type: human/system/API/scheduled-job] [role] [on device/context]
```

**Actor type** is mandatory. The system distinguishes four kinds:

| Type | Meaning | Example |
|------|---------|---------|
| `human` | A person using a UI | human user (Project Manager) on desktop browser |
| `system` | An internal service triggering an action | system (notification service) |
| `API` | An external client calling your API | API consumer (mobile app) |
| `scheduled-job` | A cron or background task | scheduled-job (nightly digest) |

Being precise here determines which builder gets the task and what kind of interface to build.

### I want

```
I want [specific action or feature]
```

State one concrete thing. Not a bundle of features — one action or capability. If the sentence has "and" in it, consider splitting the story.

### So that

```
So that [concrete benefit or outcome]
```

The benefit must be specific enough to evaluate. "So that it's easier" is not specific. "So that I can share status without giving stakeholders app access" is specific — it names a workflow and a constraint.

### Acceptance Criteria

Checkbox list. Each item must be:

- **Specific** — names the exact behavior
- **Testable** — a QA engineer can write a test for it
- **Measurable** — pass/fail is unambiguous

Minimum 3 criteria per story. Vague criteria ("the UI should feel responsive") are rejected by the system.

### Happy Path

Numbered steps describing the flow when everything works. Written from the user's perspective, not the system's. Steps should be observable actions and outcomes, not implementation details.

### Unhappy Paths

A table covering failure scenarios:

| Scenario | Trigger | Expected Behavior |
|----------|---------|-------------------|

Every story must have at least one unhappy path. Common categories to consider: network errors, empty states, permission failures, input boundary violations, concurrent operations.

### [USER DECISION] Constraints

Requirements that are locked and not open for reinterpretation. These are set by the user and propagated through the pipeline unchanged. The Architect and Builder cannot override them — they can flag a conflict but must not silently deviate.

Format the header exactly as `## [USER DECISION] Constraints` so the system can parse it.

### Visual References (optional)

Link wireframes or screenshots using the format:

```
[wireframe: flows/auth-flow.png]
```

### Open Questions (optional)

Unresolved decisions that need confirmation before the story is implemented. These block the Architect from generating tasks for this story until resolved.

---

## Full Good Example

```markdown
# US-047: Export Tasks to CSV

**As a** human user (Project Manager) on desktop browser
**I want** to export my task list to a CSV file
**So that** I can share project status with stakeholders who don't have app access

## Acceptance Criteria
- [ ] Export button is visible on the task list page
- [ ] Clicking export downloads a .csv file (not opens in browser)
- [ ] CSV includes columns: Task ID, Title, Status, Assignee, Due Date, Priority
- [ ] Tasks are filtered to the current view (same filters applied)
- [ ] Empty task list exports an empty CSV with headers only
- [ ] Filename format: tasks-YYYY-MM-DD.csv

## Happy Path
1. User opens the task list page with filters applied
2. User clicks "Export CSV" button in the toolbar
3. Browser downloads tasks-2026-03-22.csv immediately
4. File opens in Excel/Sheets with correct column headers and data

## Unhappy Paths
| Scenario | Trigger | Expected Behavior |
|----------|---------|-------------------|
| No tasks match filter | Export with empty results | Downloads CSV with headers only, no rows |
| Network timeout | Slow connection during export | Error toast: "Export failed. Try again." |
| Very large export (1000+ tasks) | Task list has 1000+ rows | Progress indicator shown, export completes |

## [USER DECISION] Constraints
- Export MUST include all columns listed above — do not omit any
- Filename MUST use the format tasks-YYYY-MM-DD.csv

## Open Questions
- Should export respect pagination or always export all matching tasks? (Assume all — needs confirmation)
```

---

## Anti-Examples

These are the most common ways user stories go wrong.

### 1. Vague actor

**Bad:** `As a user, I want to export data...`

The word "user" tells you nothing. Is this a mobile user? An admin? An API consumer? A scheduled job? The wrong actor leads to the wrong builder being assigned and the wrong interface being built.

**Fix:** `As a human user (Project Manager) on desktop browser`

### 2. Vague benefit

**Bad:** `...so that the experience is better`

A benefit that can't be evaluated is useless. "Better" for whom? In what way? How would you know if you succeeded?

**Fix:** `...so that I can share project status with stakeholders who don't have app access`

This names a specific workflow (sharing status) and a specific constraint (stakeholders without access).

### 3. Non-testable acceptance criteria

**Bad:** `- [ ] The UI should look good`

A QA engineer cannot write a test for "looks good." This criterion will be interpreted differently by every person who reads it.

**Fix:** `- [ ] Export button must have a minimum 44px touch target and be visible without scrolling on 1280px viewport`

### 4. Missing unhappy paths

**Bad:** Story only covers the happy path — what happens when everything works.

Real users encounter errors. Real systems have failures. A story with no unhappy paths produces code with no error handling.

**Fix:** Always ask: what happens if the network is slow? What if the input is empty? What if the user lacks permission? What if the operation is requested twice?

### 5. Mixed concerns

**Bad:** One story covers user login AND password reset AND Google OAuth AND session management.

This produces a task that no single builder can own cleanly, and creates file ownership conflicts between parallel builders.

**Fix:** Split into `US-012: Email Login`, `US-013: Password Reset Flow`, `US-014: Google OAuth Login`. Each story produces one or two tasks. Each task has clear file ownership.

---

## System Constraints

The following are enforced automatically:

- Stories must have at least **3 acceptance criteria**
- The actor line must specify **actor type** (human/system/API/scheduled-job)
- Stories must have at least **1 unhappy path**
- `[USER DECISION]` constraints are locked — Architect and Builder will flag conflicts but cannot override
- Stories with open questions are **not scheduled** until questions are resolved
- Wireframe references use the format `[wireframe: flows/filename.png]` — the Prototyper creates these files
