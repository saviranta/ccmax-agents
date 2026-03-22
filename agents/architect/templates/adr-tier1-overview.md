# Architecture Overview
Project: [project name]
Generated: YYYY-MM-DD
Author: integration-architect

> This is the Tier 1 architecture document. Every agent in the Builder reads this before starting work.
> Domain ADRs in `adr/` provide deeper detail for each domain. This document governs all of them.

## System Topology

[ASCII or text diagram showing components and connections]

Components:
- **[Component A]**: [what it is, what it does]
- **[Component B]**: [what it is, what it does]

## Integration Contracts

How each pair of communicating components talks to each other:

### [Component A] ↔ [Component B]
- **Protocol**: REST / GraphQL / WebSocket / message queue
- **Auth**: how the caller authenticates (header name, token type)
- **Error shape**: `{ "error": { "code": "...", "message": "...", "details": {} } }`
- **Base URL**: [environment variable name] (e.g. `API_BASE_URL`)

## Non-Negotiable Constraints

These override any domain-level decision:
- **[Constraint]**: [explanation] — [which builders this affects]

## Conflicts Resolved

| Conflict | Domain A Assumed | Domain B Assumed | Resolution |
|----------|-----------------|-----------------|------------|

## Open Questions / Gaps

- [ ] [Unresolved question — flagged for human decision]
