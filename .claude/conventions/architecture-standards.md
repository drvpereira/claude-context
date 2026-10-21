# Architecture Standards

Project-specific architecture choices that build on top of the paradigm skills. Referenced from CLAUDE.md and from the Lead Architect / Senior Java Engineer agents.

**Paradigm canon (separately maintained):**
- `.claude/skills/clean-architecture/SKILL.md` — layered architecture, dependency direction, transaction boundaries, framework isolation
- `.claude/skills/domain-driven-design/SKILL.md` — Rich Domain Model, aggregates, domain events, ubiquitous language

This file does not restate paradigm rules. It encodes how this codebase applies them.

## Design Principles

Every solution must be evaluated against these principles — they are not optional and apply at every phase, from data model to API design to implementation.

| Principle | What it means in practice |
|---|---|
| **SOLID & Clean Design** | Single responsibility, high cohesion, low coupling, separation of concerns — API, application, domain, and persistence are distinct layers, never mixed |
| **Explicitness** | Hidden behaviour is forbidden — timeouts, retries, transactions, caching, and consistency must always be explicit in code or configuration |
| **Domain Alignment & Boundaries** | Service boundaries and data models reflect the business domain and language — every boundary is explicit, documented, and enforced, with no implicit cross-feature dependencies |
| **Testability** | Every component is independently testable — no hidden dependencies, no untestable god classes |
| **Evolvability** | Design for change — new requirements should extend, not rewrite |
| **Observability** | Every service exposes metrics, structured logs, and traces sufficient to diagnose production issues without a debugger |
| **Resilience** | Failures are expected and handled — timeouts, retries, circuit breakers, and graceful degradation are designed in, not retrofitted |
| **Scalability** | Design for the expected load with headroom — no single points of contention, no assumptions of single-instance deployment |

Any proposed solution that violates one or more of these principles must explicitly state the violation, the reason it is acceptable, and the mitigation. Silent violations are not acceptable.

## Preferred Architecture

**Backend — Package by Feature (DDD, defaults, adapt to project stack):**
```
feature/
├── api/                   ← controllers
│   └── dto/               ← request/response DTOs and simple read model projections
├── domain/
│   ├── Order.java          ← domain objects: entities, aggregates, value objects
│   ├── OrderItem.java
│   ├── OrderRepository.java ← repository interfaces (defined in domain, implemented by persistence)
│   └── PricingService.java ← domain services (domain logic not belonging to a single aggregate)
├── exception/              ← caught by global exception handler
├── persistence/
│   ├── JpaOrderRepository.java ← repository implementations
│   └── mapper/             ← entity → DTO mappers (e.g. MapStruct)
└── FeatureService.java     ← application service at feature root, not in sub-package
```

- Cross-feature access: through services only — never direct repository imports across features
- Services: concrete by default. Interface only for strategy pattern — name by concept (`PaymentProcessor`), implementations by specifics (`StripePaymentProcessor`). Never `Impl`.
- Response: return DTOs directly — no envelope, no wrapper (`{ success, data, meta }` patterns are forbidden). Paginated endpoints use the standard `Page` shape defined in API contracts. Errors via global handler only — RFC 9457 Problem Details (`application/problem+json`): `{ type, title, status, detail, instance }`. Validation errors extend with `errors: [{ field, message }]`.

**Frontend — Feature-Mirrored Structure (defaults, adapt to project stack):**

```
src/features/payment/
├── api/     ← data-fetching hooks (e.g. React Query)
├── components/
└── store/   ← shared UI state slice (only if needed)
```

- Server state: prefer React Query or equivalent. Shared UI state: Zustand or equivalent. Local: useState/useReducer.
- No prop-drilling past one level.

**API versioning**: extend in place when possible. New version only on breaking change — see `.claude/conventions/engineering-principles.md` for the full breaking-change definition.

## Technical Standards

- **OpenAPI spec**: defined through annotations directly on controllers and DTOs — infer tooling from project. Never maintained as a separate YAML file. Treat annotations as the source of truth for API contracts.
- **AsyncAPI spec**: defined through annotations when async messaging is involved (Kafka, RabbitMQ, etc.) — infer tooling from project. Required for every async integration.
- **Data model**: express as entity-relation tables — not migration SQL (engineers write migrations).
- **Feature flags**: `{flow-type}.{feature}.enabled=false` — include a removal plan in the spec.
- **Service communication**: document sync vs async patterns, retry strategy, and timeout per integration.
- **Code documentation**: classes should have a short role description when the intent is not immediately obvious from the name alone. Every non-obvious logical block should have a single-line comment explaining why, not what. Enforce during PR reviews.
- **Time handling**: all persisted timestamps must be timezone-aware and stored in UTC. Timestamps without timezone information silently produce incorrect data across environments, clock drift scenarios, and DST boundaries.

## API Contract Defaults

- Every list/fetch endpoint must have pagination from first implementation
- Standard pagination response shape: `{ content, totalElements, totalPages, number }` where `number` is the zero-based page index
- Default page size: 50; maximum page size: 100 — requests exceeding the maximum must be rejected with `400 Bad Request`. Unenforced page size is a memory exhaustion vector.

## Migration Review

See `.claude/skills/database-migrations/SKILL.md` for the canonical migration patterns (file naming, append-only rule, expand-and-contract, schema-vs-data separation, index review, rollback planning). The rules below define the architect's review responsibilities at the project level.

Schema changes are architectural decisions. The architect must review and sign off on every migration before it is committed.

Review checklist:
- Change is backwards compatible with the current deployed version
- Breaking schema changes must follow the expand-and-contract pattern: (1) add new column or table, (2) deploy application code that writes to both old and new, (3) backfill existing data, (4) remove the old column or table in a subsequent release. Never remove or rename a column in the same migration that introduces the replacement.
- No column removed or renamed without a deprecation plan
- No data migration mixed with schema migration — these must be separate files
- Index additions reviewed for write performance impact
- Rollback plan documented in the spec if the migration is not trivially reversible

**Gate ✅:** Architect has signed off on all migrations before merge.

## Data Consistency

For every multi-entity or cross-service operation, define the following in the spec before implementation begins. Without this, systems drift into implicit distributed transactions.

| Concern | What to define |
|---|---|
| **Transactional boundary** | Which operations are atomic — what succeeds or fails together |
| **Consistency model** | Strong (synchronous, single transaction) or eventual (async, tolerates temporary divergence) |
| **Conflict resolution** | How concurrent writes to the same data are resolved — last write wins, version vector, domain rule |
| **Concurrency model** | Per entity: optimistic locking (default for all mutable entities — aggregate roots and child entities alike), pessimistic locking (high-contention only, justify in spec), or conflict-free (append-only or immutable). Never leave as an implementation-level decision. |
| **Compensation strategy** | What happens when part of a multi-step operation fails — Saga pattern if cross-service rollback is needed |

**Triggers** — apply this section whenever:
- An operation writes to more than one aggregate or service
- A flow involves async messaging with side effects
- A failure mid-flow would leave data in an inconsistent state
- Idempotent consumers are required

For aggregate semantics (one transaction per aggregate, cross-aggregate via domain events), see `.claude/skills/domain-driven-design/SKILL.md`.

**Gate ✅:** Consistency model, transactional boundary, and compensation strategy defined in spec before Phase 2 sign-off.

## Read Models

Read operations that require data from more than one aggregate must use dedicated read models — never load or join multiple aggregate roots through domain repositories.

**Permitted implementations:**

| Approach | When to use |
|---|---|
| **Database projection** | Simple flattened views of one or a few tables — a query that returns a DTO shape directly without loading full aggregates |
| **Query service** | Complex multi-table reads requiring application-level composition — a dedicated service with no domain behaviour |
| **Materialised view** | Expensive or frequently-read cross-aggregate queries — DB-level precomputed view, refreshed on a defined schedule or trigger |
| **Search index** | Full-text search, faceted filtering, or ranking — a dedicated search engine where query flexibility outweighs consistency guarantees |

**Rules:**
- Read models are not domain objects — they must never contain business logic or enforce invariants
- Read models are optimised for query performance only — they may flatten, join, or denormalise freely
- Read models live in `api/dto/` for simple projections, or in a dedicated `query/` package for complex query services — never in `domain/`
- A read model that accumulates conditional logic or business rules is a design smell — raise it as a spec gap immediately
- Changes to domain entities do not automatically update read models — the synchronisation strategy (synchronous, event-driven, or polling) must be defined in the spec

**Gate ✅:** Every cross-aggregate read operation has a defined read model approach in the spec before Phase 2 sign-off.

## Load Assumptions

Every feature spec must define load assumptions before architecture is finalised. Without these, scalability judgements are guesses.

| Assumption | What to define |
|---|---|
| **Expected request rate** | Requests per second under normal operation |
| **Peak load** | Maximum burst — when does it happen and how long does it last |
| **Data growth** | Row/record growth rate over time — monthly or annually |
| **Retention period** | How long data is kept — drives storage estimates and archival strategy |

If exact numbers are unknown, define a justified estimate with a stated assumption. "Unknown" is not acceptable — it means the feature has not been thought through.

Load assumptions feed directly into: index design, pagination defaults, cache strategy, database sizing, and performance budget thresholds.

**Gate ✅:** Load assumptions defined in spec before Phase 2 sign-off.

## Performance Budgets

Performance budgets are defined in Phase 1 based on load assumptions — not discovered at runtime. The thresholds below are **defaults**: use them when load assumptions do not dictate a stricter or looser target. If load assumptions suggest different targets, document the overrides in the spec explicitly.

**Phase 1 (Spec):** define API response time target and connection pool headroom as acceptance criteria for load testing. Record them in the spec alongside load assumptions.

**Phase 5 (Review):** flag design patterns likely to breach the agreed budget. Raise as `[ARCHITECT] Issue` or `[ARCHITECT] Blocker` per severity.

| Concern | Default threshold | Action |
|---|---|---|
| API response time | p99 > 500ms under expected load | Define target in spec at Phase 1. Flag at Phase 5 if design makes the target unreachable. |
| N+1 queries | N+1 detected in any flow, or not enforced by query-counting assertions in integration tests | Blocker — fix before merge. N+1 must be caught in tests, not discovered in production. Production discovery is an architectural failure. |
| Unindexed join | Any join on a column without an index | Blocker — add index or redesign the query |
| High join complexity | >3 joins on a hot path | Review prompt — not a blocker by itself. Verify all join columns are indexed and the query plan is acceptable before proceeding |
| Unbounded query | No pagination on list endpoint | Blocker — fix before merge |
| Unbounded page size | No maximum page size enforced at the API layer | Blocker — enforce maximum page size per API contract defaults. |
| Single point of contention | Any shared mutable state under concurrent load | Raise to user, propose solution |
| Single-instance assumption | Any design that cannot scale horizontally | Raise to user before spec sign-off |
| Connection pool saturation | Pool usage > 80% sustained | Define headroom target in spec at Phase 1 based on expected concurrency. Flag at Phase 5 if connection usage model makes saturation likely. |

Performance concerns discovered during implementation that were not caught in planning must be raised to the user immediately — do not work around them silently.
