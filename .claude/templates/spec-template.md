# Feature Spec — Full Template

Reference template for a full feature spec. Use this when a feature is non-trivial: multiple services, new data model, new API contract, async flows, security, or significant UX. For most changes, the Compact Spec defined in `.claude/skills/planning/SKILL.md` is sufficient.

**File location:** `docs/specs/YYYY.MM.DD-feature-name/YYYY.MM.DD-feature-name.md` — spec file named identically to its directory.

---

## Template

```markdown
# File: docs/specs/YYYY.MM.DD-feature-name/YYYY.MM.DD-feature-name.md

# [Feature Name]
Version: 1.0 | Status: Draft | Date: [date]

## Overview
[2-3 sentences: what, why, who]

## Goals / Out of Scope

## Business Value & Success Metrics
| Metric | Baseline | Target | How Measured |

## Requirements
### Functional
| ID | Requirement | Priority (Must/Should/Could) |
### Non-Functional
| ID | Metric (hard number or named standard) |

## Business Scenarios
Given/When/Then — happy path, edge cases, failure cases

## Risks & Mitigations
| Risk | Likelihood | Impact | Mitigation |

## Data Model
Modeling Strategy: Rich Domain Model | Transaction Script
Rationale: [short explanation]

[Entities, relations, indexes, retention — not migration SQL]

## Aggregate Boundaries
[For each aggregate: root entity, child entities owned by the root, and cross-aggregate references held by ID only. Determines repository scope, transaction scope, and domain event emission points. Omit if the feature has no aggregates (Transaction Script strategy).]

## Data Consistency
[Transactional boundary, consistency model, conflict resolution, concurrency strategy per entity (optimistic / pessimistic / conflict-free), compensation strategy]

## Domain Events
[For each aggregate that emits events: event name (past tense), emitting aggregate, triggering state transition, payload schema (primitives and IDs only — no entity references), expected consumers, and publication approach (Transactional Outbox or @TransactionalEventListener AFTER_COMMIT). Omit section if no domain events.]

## Read Models
[For each cross-aggregate read operation: implementation approach (projection / query service / materialised view / search index) and synchronisation strategy (synchronous / event-driven / polling). Omit if all reads are within a single aggregate.]

## Caching Strategy
[For each endpoint or aggregate where caching applies: what is cached, TTL, cache key composition (including all discriminators), invalidation trigger, and implementation pattern (cached repository / @Cacheable). Omit if no caching applies.]

## Load Assumptions
| Assumption | Value |
|---|---|
| Expected request rate | [req/s under normal operation] |
| Peak load | [burst — when and how long] |
| Data growth | [row growth rate, monthly or annually] |
| Retention period | [how long data is kept] |

## API Contract
### Endpoints
[Method, path, auth, request, response, error codes, idempotency strategy per endpoint]

### External Integrations
| Integration | Failure Behaviour | Timeout | Retry | Circuit Breaker | Observable |

## Architecture Diagrams
![Main Flow](./flow-main.png)
[mmdc -i flow-main.mmd -o flow-main.png]

## UX Design
[User flow, ASCII wireframes, component decisions — full UX involvement only]

## Security
[AuthN/AuthZ, encryption, compliance, audit log events + retention]

## Test Plan
### Critical Paths
### Key Test Cases
| ID | Scenario | Type | Platform | Expected Result |

## Platform Notes
[Cross-platform differences only]

## Open Questions
| # | Question | Owner | Priority |

## Revision History
| Version | Date | Author | Changes |
```
