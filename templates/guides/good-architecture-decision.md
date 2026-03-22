# Guide: Writing Architecture Decision Records (ADRs)

An Architecture Decision Record captures a significant technical decision: what was chosen, why it was chosen, what was rejected, and what the consequences are. ADRs are the primary mechanism for communicating architectural constraints to the Builder agents that follow.

---

## When to Write an ADR

Write an ADR when making a decision that involves real tradeoffs and will be difficult or costly to reverse.

**Write an ADR for:**
- Choosing between technologies, libraries, or patterns with meaningful tradeoffs (e.g., Supabase vs PlanetScale, REST vs GraphQL, JWT vs sessions)
- Deciding on an API contract that multiple components will depend on (changing it later breaks callers)
- Making a security or compliance decision (auth strategy, data residency, encryption approach)
- Choosing a data model structure that is expensive to migrate later (schema shape, normalization level, ID strategy)
- Establishing a system-wide pattern that all builders must follow (pagination style, error shape, file organization)

**Do not write an ADR for:**
- Implementation details (how to structure a single function)
- Styling choices (color palette, spacing system — these go in design-constraints.md)
- Variable and function naming
- Decisions that are trivially reversible

If you are unsure, ask: "If a Builder makes the opposite choice, does it break something that's hard to fix?" If yes, write an ADR.

---

## Structure

### Header Fields

```markdown
**Status:** Draft | Proposed | Accepted | Deprecated | Superseded by ADR-NNN
**Deciders:** [who participated in the decision — e.g., Architect, User, CTO]
**Date:** YYYY-MM-DD
```

Status moves from `Draft` (being written) → `Proposed` (awaiting approval at the architecture review gate) → `Accepted` (approved) → `Deprecated` or `Superseded` (if reversed later).

### Context

Describe the situation that made this decision necessary. Include:
- What the application needs to do
- The constraints that matter (timeline, budget, team skills, existing infrastructure, compliance)
- Why a decision is needed now

The context should be self-contained — someone reading the ADR six months later should understand why this was a decision at all.

### Decision

One or two sentences. State what was chosen directly. Not "we are considering" — "we are using X."

### Rationale

Why this option over the alternatives. Connect the rationale to the constraints stated in the context. A rationale that doesn't reference the constraints is incomplete.

### Alternatives Considered

A table:

| Option | Pros | Cons | Why Rejected |
|--------|------|------|--------------|

List every option that was seriously considered. "We didn't look at alternatives" is not a valid ADR — it means the decision was made without sufficient analysis.

### Consequences

Three categories:

- **Easier:** what this decision makes simpler
- **Harder:** what this decision makes more difficult (tradeoffs must be honest)
- **New risks:** what new failure modes or dependencies this introduces, and how they are mitigated

### Builder Constraints

This section is parsed and enforced by the build system. It tells Builder agents exactly what they must and must not do as a result of this decision.

Write constraints as imperative statements:
- `MUST use X` — required
- `MUST NOT use Y` — prohibited
- `ALWAYS do Z` — always required
- `NEVER do W` — never allowed

Be specific. "Use Supabase for auth" is less useful than "MUST use `supabase.auth` client methods — never implement token validation manually."

---

## Full Example

```markdown
# ADR-007: Use Supabase for Authentication Instead of Custom JWT

**Status:** Accepted
**Deciders:** Architect, User
**Date:** 2026-03-22

## Context
The application needs user authentication. We have two viable options: Supabase Auth (a managed
service) or a custom JWT implementation. The team has limited time and this is a v1 product.

Key constraints:
- Must support email/password and Google OAuth
- Must work with Supabase database (already chosen for the data layer — see ADR-003)
- Must be production-ready within the current eight-week timeline

## Decision
Use Supabase Auth.

## Rationale
Supabase Auth handles token refresh, session management, and OAuth flows out of the box. Building
these correctly from scratch would take 2-3 weeks and introduce substantial security risk. Given
the timeline constraint and the existing Supabase dependency, the integration overhead is minimal
and the tradeoffs clearly favor the managed service.

## Alternatives Considered
| Option | Pros | Cons | Why Rejected |
|--------|------|------|--------------|
| Custom JWT | Full control, no vendor lock-in, no additional cost | 2-3 weeks to implement securely; high risk of subtle token handling bugs | Timeline and security complexity |
| Auth0 | Battle-tested, excellent developer experience, supports all OAuth providers | Additional service cost ($23+/month), not integrated with Supabase, adds another vendor dependency | Cost and integration overhead given existing Supabase dependency |
| NextAuth.js | Open source, popular in Next.js ecosystem, adapter-based | Requires self-managing session DB or adapter config; less integrated with Supabase Row Level Security | Integration complexity with Supabase RLS negates the benefit |

## Consequences
**Easier:** Google OAuth, email verification, password reset, and session refresh are built-in and
require minimal configuration. Supabase Row Level Security works directly with Supabase Auth user
IDs.

**Harder:** If the application ever migrates away from Supabase, authentication must be replaced
at the same time — they are coupled. Customizing auth flows beyond Supabase's supported options
(e.g., multi-step registration with custom fields) requires workarounds.

**New risks:** Application login availability is dependent on Supabase Auth service availability.
Mitigate with Supabase's 99.9% uptime SLA and by implementing graceful degradation (clear error
messages when auth service is unreachable rather than silent failures).

## Builder Constraints
- MUST use `supabase.auth` client methods for all authentication operations — never implement
  token parsing or validation manually
- MUST NOT store session tokens in localStorage — Supabase handles session persistence via
  httpOnly cookies
- MUST NOT create custom JWT signing logic — Supabase issues and validates all JWTs
- Auth middleware lives at `src/lib/auth/middleware.ts` — only builder-systems may modify this
  file; all other builders MUST import from it, not reimplement auth checks
- Row Level Security policies MUST use `auth.uid()` from Supabase — do not use application-layer
  user ID checks as a substitute for RLS
```

---

## Short ADR Example

Not every decision needs the full treatment. For narrower decisions — patterns and conventions rather than technology choices — a short ADR is appropriate.

```markdown
# ADR-012: Use Cursor-Based Pagination for All List Endpoints

**Status:** Accepted
**Date:** 2026-03-22

## Context
Task list endpoints will return large datasets. The application needs a consistent pagination
strategy across all list endpoints. Two approaches are viable: offset-based and cursor-based.

## Decision
Cursor-based pagination using an opaque `cursor` query parameter (base64-encoded position value).

## Why Not Offset Pagination
Offset pagination has a race condition: if new records are inserted between page requests, items
shift and some records are skipped or duplicated across pages. For a task management application
where tasks are created frequently, this is a real problem for users paginating through large
lists. Cursor-based pagination is stable regardless of concurrent inserts.

## Consequences
**Easier:** Consistent, stable pagination across all endpoints; no duplicate or skipped items.
**Harder:** Cannot jump to an arbitrary page number (page 5 of 20). Acceptable for this use case.
**New risks:** Cursors become invalid if the sort order changes. Document this behavior clearly.

## Builder Constraints
- ALL list endpoints MUST accept `?cursor=<value>&limit=<n>` query parameters
- `limit` must default to 20 and be capped at 100 — never return unlimited results
- Response shape MUST be: `{ data: [...], nextCursor: "<value>" | null, hasMore: boolean }`
- Cursors MUST be opaque (base64-encoded) — clients must not parse or construct them
- NEVER implement offset-based pagination for any list endpoint
```

---

## ADR Quality Checklist

Before marking an ADR as Proposed, verify:

- [ ] Context explains the constraints that drove the decision (not just "we needed to choose")
- [ ] Decision is stated directly and unambiguously
- [ ] At least two alternatives are considered in the table
- [ ] Consequences section is honest about what becomes harder (not just what becomes easier)
- [ ] Builder Constraints use MUST / MUST NOT / ALWAYS / NEVER language
- [ ] Builder Constraints are specific enough to be enforceable (file paths, method names, response shapes)
- [ ] Status is set correctly (Draft while writing, Proposed at the review gate)
