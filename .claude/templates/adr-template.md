# ADR Template

Architecture Decision Record template. Use this for every major architectural choice. Without an ADR, architecture knowledge disappears from the codebase — future decisions are made without understanding past constraints and context.

**Store at:** `docs/decisions/YYYY-MM-DD-short-title.md`

**What qualifies as a major decision:**
- Choice of architectural pattern (e.g. event-driven vs request-response)
- Data consistency model for a cross-service flow
- API versioning strategy
- Choice to introduce a new external dependency or service
- Aggregate boundary definitions for a new bounded context or major feature
- Introduction of domain events for cross-aggregate or cross-service coordination
- Any decision that, if changed later, would require significant rework

**Gate ✅:** ADR written and linked from the spec for every major decision made in Phase 1 before spec sign-off.

---

## Template

```markdown
# ADR: [Short title]
Date: [YYYY-MM-DD]
Status: [Proposed | Accepted | Superseded by ADR-XXX]

## Context
[What situation or constraint forced this decision? What problem are we solving?]

## Options Considered
[Each option with a brief tradeoff summary]

## Decision
[Chosen solution and the primary reason]

## Consequences
[What becomes easier, what becomes harder, what is now constrained]
```
