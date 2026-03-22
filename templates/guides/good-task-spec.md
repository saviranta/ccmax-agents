# Guide: What Makes a Good Task Specification

A task spec is the Architect's instruction to a Builder. It must be complete enough that the Builder can write the code without needing to ask questions. If a Builder has to make a decision that isn't covered by the spec, the spec is incomplete.

---

## Structure

Every task spec requires the following elements.

### Assignment

```
Assigned to: [builder type]
```

Valid builder types:

| Type | Responsibility |
|------|---------------|
| `builder-ui` | React components, pages, client-side logic |
| `builder-api` | API routes, server-side handlers, middleware |
| `builder-data` | Database schemas, migrations, queries, seeds |
| `builder-systems` | Auth, caching, queuing, platform config |
| `builder-integration` | Third-party APIs, webhooks, external services |
| `builder-ml` | Model inference, embeddings, AI pipelines |
| `builder-mobile` | Native mobile (React Native / Swift / Kotlin) |
| `builder-realtime` | WebSockets, SSE, presence, subscriptions |
| `builder-infra` | CI/CD, environment config, Dockerfile, IaC |
| `builder-composer` | Cross-cutting tasks that coordinate other builders |
| `auto` | System selects the best-fit builder at runtime |

### Phase and Milestone

```
Phase: phase-N
Milestone: mvp | v1 | v2
```

Phase determines when the task runs in the build sequence. Milestone determines which stable release this work belongs to.

### Size

```
Size: S | M | L
```

| Size | Time | Files Owned | When to Use |
|------|------|-------------|-------------|
| S | < 1 hour | 1-2 files | Single function, single component, config change, migration file |
| M | 1-4 hours | 2-5 files | A complete feature slice: endpoint + service + basic tests |
| L | > 4 hours | 5+ files | Multiple interconnected features or system-wide concern |

**L-sized tasks are always split.** The mini-architect sub-agent breaks them into S/M tasks before any builder runs. If you find yourself listing 6+ owned files, the task is L-sized — mark it as such and let the system split it rather than trying to scope it down artificially.

### Dependencies

```
depends_on: [task-021, task-022]
```

List task IDs that must be complete before this task can start. A dependency means: their owned files exist and are complete.

**Important distinction:**
- Use `depends_on` when you need a file to exist and be in its final state (you'll import from it, call its functions, or build on its schema)
- Use `files_to_read` when you just need to reference a file for context but don't depend on it being complete

Circular dependencies (`task-A → task-B → task-A`) are a spec error. The fix is to extract the shared interface into a new task that both depend on.

### Owns Files

```
owns_files:
  - src/app/api/tasks/route.ts
  - src/lib/tasks/create.ts
  - src/lib/tasks/types.ts
  - tests/unit/tasks/create.test.ts
```

**This is the most critical field in the entire task spec.**

`owns_files` is a mutual exclusion lock. No two tasks that run in parallel may claim the same file. If they do, the build system will detect the conflict and block one task until the other completes.

Rules for `owns_files`:

1. List **every file this task will write or meaningfully modify** — not just create, but also modify
2. If you're unsure whether to include a file, include it
3. Specific file paths only — never a directory (`src/lib/` is not valid)
4. If two tasks both need to modify the same file, either serialize them (one depends on the other) or extract the shared concern into a separate task

### Files to Read

```
files_to_read:
  - src/lib/auth/middleware.ts (lines 1-50: how auth is applied)
  - src/lib/db/client.ts (lines 1-30: DB client setup)
```

Files to read for context. The builder will not modify these. Include line ranges when you know which part is relevant — this reduces noise.

### Interface / Schema Specification

The exact TypeScript types, database schemas, or API contracts the builder will implement. This section must be copy-paste ready — not a description of what the interface should look like, but the actual interface.

If the task defines a contract that other tasks depend on (e.g., a shared type), this section is how that contract is communicated.

### Behavior Rules

Explicit rules governing the implementation. Written as declarative statements:

- "POST /api/tasks requires authenticated user (401 if no session)"
- "New task status is always 'pending' regardless of request body"
- "Title max 200 characters (400 if too long)"

Each rule should be a complete sentence with the condition and expected result.

### Edge Cases

Scenarios that fall outside the happy path but are not errors. Must be explicitly handled:

- Concurrent operations
- Boundary values (empty string, max length, zero, negative numbers)
- Missing optional fields
- Idempotency requirements

### Unit Test Requirements

What must be tested, not how to write the tests. The builder chooses the testing approach; the spec defines the coverage requirements.

Minimum 3 test cases per task. Format as:

- `Test: [scenario] → [expected outcome]`

### Acceptance Criteria

Checkboxes that match (or trace to) the acceptance criteria in the linked user stories. A task is complete when all checkboxes pass.

---

## Full Good Example

```markdown
# task-034: Task Creation API Endpoint

**Assigned to:** builder-api
**Phase:** phase-2
**Milestone:** mvp
**Size:** M

## Dependencies
- task-021 (database schema must be migrated first)
- task-022 (auth middleware must be working — this endpoint requires authentication)

## Owns Files (exclusive — no other parallel task may touch these)
- src/app/api/tasks/route.ts
- src/lib/tasks/create.ts
- src/lib/tasks/types.ts
- tests/unit/tasks/create.test.ts

## Files to Read (context only)
- src/lib/auth/middleware.ts (lines 1-50: how auth is applied)
- src/lib/db/client.ts (lines 1-30: DB client setup)
- .max-agents/artifacts/architect/api-contracts.json (tasks.create spec)

## Interface Specification

```typescript
// Request body
interface CreateTaskRequest {
  title: string;           // required, max 200 chars
  description?: string;    // optional, max 10,000 chars (truncated silently if exceeded)
  dueDate?: string;        // optional, ISO 8601, must be future date
  assigneeId?: string;     // optional, must be valid user ID in same project
  priority?: 'low' | 'medium' | 'high';  // optional, default: 'medium'
}

// Success response (201)
interface CreateTaskResponse {
  id: string;
  title: string;
  description: string | null;
  status: 'pending';       // always 'pending' on creation
  dueDate: string | null;
  assigneeId: string | null;
  priority: 'low' | 'medium' | 'high';
  createdAt: string;
  createdBy: string;       // authenticated user ID
}

// Error response (4xx)
interface ErrorResponse {
  error: string;
  field?: string;          // present for validation errors
}
```

## Behavior Rules
- POST /api/tasks requires authenticated user (401 if no session)
- Title is required, max 200 characters (400 if missing or too long)
- Due date must be in the future at time of creation (400 if past)
- New task status is always "pending" regardless of request body
- Description exceeding 10,000 characters is truncated silently — no error
- Returns 201 on success with the full task object

## Edge Cases
- Concurrent creation: no unique constraint on title, duplicates are allowed
- Very long description (> 10,000 chars): truncate to 10,000 chars, do not return error
- Missing optional fields (description, dueDate, assigneeId): set to null in DB
- Invalid assigneeId (user not in project): return 400 with field: "assigneeId"

## Unit Test Requirements
- Test: successful creation returns 201 with correct shape and status: "pending"
- Test: missing title returns 400 with field: "title"
- Test: unauthenticated request returns 401
- Test: past due date returns 400 with field: "dueDate"
- Test: description at 10,001 chars is truncated to 10,000 in the returned object
- Test: invalid assigneeId returns 400 with field: "assigneeId"

## Acceptance Criteria
- [ ] POST /api/tasks creates a task and returns 201
- [ ] Unauthenticated requests are rejected with 401
- [ ] Validation errors return 400 with the field name
- [ ] Description over 10,000 chars is truncated without error
```

---

## Anti-Examples

### 1. Vague owns_files

**Bad:** `owns_files: ["src/lib/"]`

A directory is not a valid value. The build system cannot enforce mutual exclusion on a directory — two parallel tasks could both claim `src/lib/` and still collide on the same file inside it.

**Fix:** List every specific file: `src/lib/tasks/create.ts`, `src/lib/tasks/types.ts`

### 2. Circular dependency

**Bad:** task-A depends on task-B; task-B depends on task-A

Neither task can start. This is a spec error, not a runtime condition the build system can resolve.

**Fix:** Identify the shared contract that both need. Extract it into task-C (usually an interface or schema definition). Both task-A and task-B depend on task-C.

### 3. Missing interface specification

**Bad:** "The endpoint accepts task data and returns the created task."

A builder reading this has to invent the interface. Two builders working on related tasks may invent incompatible interfaces.

**Fix:** Provide the exact TypeScript interface, database schema, or API contract. Copy-paste ready means the builder can drop it directly into the code.

### 4. Missing edge cases

**Bad:** Spec only covers the happy path — valid input, authenticated user, everything works.

Real code must handle real inputs. Omitting edge cases means the builder will either miss them (producing bugs) or make their own decisions (producing inconsistent behavior).

**Fix:** For every input field, consider: what if it's missing? What if it's empty? What if it's at the maximum? What if it's invalid? For every operation, consider: what if it's called twice? What if the database is unavailable?

### 5. No unit test requirements

**Bad:** Task spec with no test section, or with: "Write tests as appropriate."

"As appropriate" means different things to different builders. Without explicit test requirements, coverage is inconsistent and critical paths go untested.

**Fix:** Every task must specify at least 3 test cases as `Test: [scenario] → [expected outcome]`.

---

## Common Mistakes

**Claiming a file that another parallel task also claims.** The build system detects this and serializes the tasks, which can cascade into blocking an entire batch. At the task graph review gate, check for file ownership conflicts between tasks in the same phase.

**Forgetting to list files in `owns_files` that the task will actually write.** If a builder modifies a file that isn't in its `owns_files`, another builder running in parallel may write to the same file simultaneously, causing a race condition that corrupts both tasks' output.

**Making M-sized tasks too broad.** If you cannot list the owned files precisely because the task "touches a lot of things," the task is L-sized. Mark it L and let the mini-architect split it. Forcing a broad task into M-sized clothing produces under-specified specs and merge conflicts.
