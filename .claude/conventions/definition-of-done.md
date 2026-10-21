# Definition of Done

Pre-merge checklist. Referenced from `CLAUDE.md`.

A change is done only when every item below is true — no exceptions, no partial credit.

## Spec & Tests
- Spec created or updated before any code was written
- All acceptance criteria from the spec have corresponding passing tests
- 90%+ unit test coverage on new and modified code

## Code Quality
- No magic strings or magic numbers
- All user-facing strings internationalised — no hardcoded copy

## Endpoints
Every new endpoint must have:
- Authentication and authorisation enforced (per project auth standards)
- Pagination enforced on all list endpoints
- Metrics instrumented
- Structured logging in place

## UI Components
Every new UI component must have:
- Isolated visual test
- `data-testid` attribute (web) / `testID` attribute (mobile)

## Sign-offs
- No unresolved Blockers
- UX section in the spec matches the delivered implementation (skip if no UX surface)
- All agents have signed off per the Agreement & Consensus Definition
- Pre-merge checklist complete (defined in `.claude/skills/planning/SKILL.md`)

## Commit
- Correct branch naming followed (`feature/` or `hotfix/`, with ticket ID prefix if applicable)
- Commit message references the spec file and describes the change
