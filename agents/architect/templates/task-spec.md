# Task NNN: [Title]

## Assignment
[builder type: builder-composer | builder-systems | builder-data | builder-integration | builder-ui | builder-infra | auto | builder-ml | builder-realtime | builder-mobile | builder-api]

## Phase / Milestone
[phase-N] / [MVP | V1 | V2]

## Size
[S | M | L]

## Dependencies
- task-NNN ([task title] — must exist: [specific file path or function that must be present])

## Files to Create (this task owns these — no other parallel task may touch them)
- [exact/file/path.ext]
- [exact/file/path.test.ext]

## Files to Read (with relevant sections)
- [exact/file/path.ext] (lines NNN-NNN: [what's relevant there])
- .max-agents/artifacts/architect/architecture/overview.md (integration contracts section)
- .max-agents/artifacts/architect/conventions.md (all sections)

## Specification

### [Component/Function/Module Name]
```[language]
[exact interface, prop types, function signature, or schema]
```

### Behavior
- [Specific behavior rule 1]
- [Specific behavior rule 2]
- [Edge case handling]

### [Additional sections as needed: API Behavior, State Shape, Event Schema, etc.]

## Test Requirements (unit tests — bundled with this task)
- [Specific test: what to test, what the expected outcome is]
- [Another test]

## Acceptance Criteria
- [ ] [Specific, testable criterion]
- [ ] [Another criterion]
- [ ] TypeScript compiles with no errors (if TS project)
- [ ] All unit tests pass
- [ ] All conventions in conventions.md followed
