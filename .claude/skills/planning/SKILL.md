---
name: planning
description: Orchestration skill for Phases 1–2 of the core workflow. Runs requirement gap analysis, kills vague language, surfaces technical risks, locks test scope, and produces the feature spec. Use when starting any new feature, bug fix, or change.
---

# Planning Skill

Operates within Phase 1 of the Core Workflow (CLAUDE.md). Human is the orchestrator — agents propose, human directs.

**Core loop**: Agents analyse → present findings to human → human adds direction/ideas/constraints → agents refine → spec written.

**Never write the spec before the human has had a chance to add direction.** Even if everything looks clear to agents, ask. The human has context agents cannot have.

---

## When to Use
- Starting any new feature, bug fix, or change — Phase 1 of the workflow
- At every Phase 1 or Phase 2 gate
- Spec writing — Compact Spec or full template from `.claude/templates/spec-template.md`
- When the user pushes back with "just build it" — see § When User Pushes Back

---

## The Spec Is the Source of Truth
If the spec is crisp → coding is fast and controlled. If it is fuzzy → coding becomes planning by accident.

**Default output — Compact Spec** (most changes):
```
1. What problem are we solving?
2. What does done mean? (testable — if untestable, it is not done)
3. Scenarios: happy path / edge case / failure case (Given/When/Then)
4. What can break technically? (specific to this feature)
5. How will we test it? (unit / integration / E2E)
6. What is explicitly out of scope? (at least two items)
```

**Full spec**: use when complexity demands it — multiple services, new data model, new API contract, async flows, security, significant UX. See template below.

---

## Gate Flow

Gates run in sequence. At each gate: agents analyse first, then ask the human for input before proceeding.

### Requirement Gap Analysis
Agents surface gaps in: acceptance criteria, business scenarios (≥1 Given/When/Then), business value, success metrics.

**Then ask the human**:
> *"Based on this analysis, do you have additional business context, edge cases we may have missed, or constraints we should factor in?"*

Wait for response. Incorporate human input before moving on.

---

### Kill Vague Language
Flag: *fast, secure, scalable, reliable, real-time, intuitive, simple, robust*. Propose concrete replacements with hard numbers or named standards.

**Then ask the human**:
> *"We've proposed these metrics. Do these match your intent, or are there specific thresholds you have in mind?"*

---

### Technical Gap Analysis
Agents flag genuinely unknown items: `[Area] — Missing: [what] / Why: [consequence] / Default: [fallback]`

Cover: production risks specific to this design (e.g. race conditions, missing indexes, cascade deletes — think beyond these examples), data model, API contracts, security, external integrations (failure behaviour, timeout, retry, circuit breaker, observability).

**Then ask the human**:
> *"Here are the technical risks and unknowns we've identified. Do you have past experience with this kind of system that changes how we should approach any of these? Any architectural preferences or things we should avoid?"*

This is where the human's domain knowledge changes the design. Do not skip this.

---

### Testing Strategy (The Break)
Identify critical paths. Propose test scenarios covering: happy path, edge cases, failure cases.

- Unit: 90%+ business logic. Nulls, empty values, invalid inputs.
- Integration: all happy + negative paths. Mock external dependencies.
- E2E: 100% happy paths only.

**Test scope is agreed here and locked.** Once the human confirms and Phase 1 signs off, tests may not be changed in Phase 5 to accommodate implementation choices. If an implementation cannot pass an agreed test — the implementation is wrong. This is stated explicitly so there is no ambiguity later.

**Then ask the human**:
> *"These are the breaking scenarios we plan to test. Are these the right things to break? What failure modes are you most worried about that we haven't covered? Once we agree this, the test scope is locked."*

Human defines what "broken" means. Agents write tests after human confirms.

UX Designer reviews test scenarios before finalising — specifically checking for missing user-initiated flows, branching paths not covered (e.g. empty states, error recovery), and flows that are technically correct but violate expected UX behaviour. If a concern is raised, it blocks sign-off until resolved.

---

### Final Feature Spec
**Before writing**: confirm human has had input at every gate above.

**Before sign-off**: The workflow asks every agent "What would stop you implementing this without another question?" Then asks the human:
> *"Here is the complete spec. Before we sign off and move to writing tests — is there anything you'd like to change, any concern you want addressed, or any direction you want to add?"*

Human acknowledgement is required. Sign-off = commitment to execute without interrupting delivery.

Spec approval is a major decision — all agents must explicitly sign off before proceeding to Phase 3 (Spec Delivery).

Phase 3 writes the agreed spec to disk: `docs/specs/YYYY.MM.DD-feature-name/YYYY.MM.DD-feature-name.md` — spec file named identically to its directory. Diagrams: `mmdc -i <file>.mmd -o <file>.png`. No new decisions at Phase 3 — everything must be resolved here in Phase 2 before writing begins.

---

## Spec Template (Full)

For non-trivial features, use the full spec template at `.claude/templates/spec-template.md`. For most changes, the Compact Spec format defined above is sufficient.

---

## Pre-Merge Checklist

Run before creating the PR. Every item must be true — no exceptions.

**Spec**
- [ ] Spec file created or updated before any code was written
- [ ] All acceptance criteria from the spec have corresponding passing tests
- [ ] Bug fixes: spec updated under `## Bug Fixes` with root cause and fix description

**Tests**
- [ ] All unit and integration tests pass
- [ ] No tests were modified to fit the implementation (only allowed if the spec changed or the test was provably wrong — requires QA approval)
- [ ] 90%+ unit test coverage on new and modified code

**Code**
- [ ] No business logic in controllers or repositories
- [ ] No `@Transactional` at class level — declared per method only
- [ ] No external I/O inside a DB transaction
- [ ] No PII or credentials in any log statement
- [ ] No magic strings or magic numbers
- [ ] All user-facing strings internationalised

**Endpoints** (if new endpoints added)
- [ ] Authentication and authorisation enforced
- [ ] Pagination on all list endpoints
- [ ] `Location` header on `201 Created` responses
- [ ] Error responses use RFC 9457 Problem Details (`application/problem+json`)
- [ ] Metrics and structured logging in place

**UI Components** (if new UI components added)
- [ ] Isolated visual test
- [ ] `data-testid` attribute on web components / `testID` attribute on mobile components

**Branch and commit**
- [ ] Branch created from `main` after pulling latest
- [ ] Branch named `feature/` or `hotfix/` (with ticket ID prefix if applicable)
- [ ] Commit message references the spec file

**Sign-offs**
- [ ] No unresolved Blockers
- [ ] UX section in the spec matches the delivered implementation (skip if no UX surface)
- [ ] All agents have signed off per the Agreement & Consensus Definition

---

## Bug Fix Mode

Bug fixes follow the same gate flow as new features — all phases apply in full. The differences are:

- **Spec format**: use the Compact Spec (not the full template) unless the bug exposes a broader design problem that warrants a full spec
- **Spec location**: add a `## Bug Fixes` section to the nearest relevant existing spec file; create a new spec file only if none exists. Each entry must include: reproduction steps, expected vs actual behaviour, root cause, and fix description
- **Requirement Gap Analysis**: focus on the reproduction path — confirm the bug can be reliably reproduced before opening the gap analysis. If it cannot be reproduced consistently, raise it to the user before proceeding
- **Testing Strategy gate**: a failing test that reproduces the bug must exist and be agreed before the planning phase closes. No fix may begin without it
- **Branch**: `hotfix/` prefix, not `feature/`

---

## When User Pushes Back
- "Just build it" → proceed, flag unresolved assumptions inline
- "I already know this" → take their answer, clear gate immediately

---

## Related Skills

- `session-handover` — produce a handover when planning spans multiple sessions
- `mermaid-diagrams` — diagrams are part of the full spec
- `domain-driven-design` — domain modelling decisions made during planning
- `clean-architecture` — layered architecture decisions made during planning
