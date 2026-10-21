---
name: domain-driven-design
description: DDD tactical and strategic patterns. Use when modelling a new feature's domain, deciding aggregate boundaries, defining domain events, reviewing for anemic-model violations, or designing repositories per aggregate root.
---

# Domain-Driven Design

Answers the question **"How do I model this concept?"** Covers Rich Domain Model vs anemic, aggregates and roots, value objects, domain events, ubiquitous language, and repositories per aggregate. Paradigm canon — stack-agnostic, reusable across agents. For this project's specific implementation choices (package layout, ORM, frameworks), see `.claude/conventions/architecture-standards.md` and `.claude/skills/jpa-patterns/SKILL.md`.

## When to Use
- Modelling a new feature's domain — choosing between Rich Domain Model and Transaction Script
- Defining aggregate boundaries before implementation begins
- Designing domain events for cross-aggregate or cross-service coordination
- Reviewing code for anemic-model violations or misplaced business rules
- Choosing between Transactional Outbox and `@TransactionalEventListener(AFTER_COMMIT)` for event publication

---

## Domain Modeling Strategy

Choose the modeling approach before any data model or aggregate work begins, and document it explicitly in the spec.

**a) Rich Domain Model** is the standard — entities encapsulate behaviour, enforce invariants, and own their state transitions. Anemic models (plain data objects with logic in services) are not acceptable and will be flagged as a blocker during review.

**b) Transaction Script** is a narrow exception — permitted only for purely mechanical CRUD with no business rules, no state machine, and no invariants to protect. It requires explicit justification in the spec and sign-off from the Architect. If there is any doubt, use Rich Domain Model.

The chosen strategy must appear in the spec as:
```
Modeling Strategy: Rich Domain Model | Transaction Script
Rationale: <short explanation>
```

Once chosen, the strategy must be applied consistently within the feature — mixing approaches inside a single bounded context is not permitted without explicit justification.

The Engineer must review and confirm implementation feasibility of the chosen strategy during Phase 1 before spec sign-off. If implementation constraints (ORM limitations, transactional complexity, performance) require reconsidering the strategy, the Engineer raises this before the spec is closed — not during Phase 5.

## Rich Domain Model — Rules

Domain objects encapsulate business behaviour and protect invariants. The model is the heart of the application — if business rules live in services, the domain is just a data bag.

- **Expose behaviour, not setters** — entities have methods that represent business actions, not generic `setX()` mutations. If the caller can set any field directly, the entity cannot protect itself.
- **State transitions through explicit methods** — `order.cancel()`, `seat.reserve()`, `account.deactivate()` — transitions carry intent, enforce rules, and can raise domain events. A direct field assignment carries none of these.
- **Enforce invariants inside the entity** — if an invariant can be violated from outside the entity, it is not enforced. An entity that requires a non-null `customerId` must check this itself, not rely on callers to remember.
- **Invalid states must be impossible to construct** — use constructors or factory methods that validate all required fields and preconditions. An entity that can exist in an invalid state will eventually be in one.
- **Constructors and factory methods guarantee valid state** — every path to constructing an entity must produce a valid object. Partial construction followed by a chain of setters is forbidden.
- **Persistence-ignorance where practical** — domain objects should not know about JPA, SQL, or serialisation concerns. Annotations are acceptable on entities, but domain logic must not depend on them.
- **No lazy-loading side effects in constructors or domain methods** — constructors and domain methods must be executable using only the state already loaded within the aggregate boundary. The application service is responsible for loading all required data before invoking them. A constructor or method that silently triggers a lazy-load, fails silently, or behaves differently depending on what the ORM has loaded violates persistence-ignorance — it is an ORM artefact, not a domain object.
- **Immutable collection exposure** — entity collections must never be exposed as mutable. Aggregate roots must return read-only views (e.g. `Collections.unmodifiableList`, `List.copyOf`) or expose intention-revealing methods only. Callers must never be able to mutate internal collections directly.
- **Services orchestrate, entities decide** — a service may ask `order.canBeCancelled()` and then call `order.cancel()`, but the rule "what makes an order cancellable" lives in the entity, not the service.
- **No public setters on aggregate roots for invariant-bearing fields**

## Aggregate Boundaries

Aggregates define transactional consistency boundaries. Without explicit boundaries, rich domain models degenerate into tangled object graphs where any object can modify any other, and transactions become unbounded.

**Spec requirement**: for every feature, define aggregate roots explicitly. For each aggregate: identify the root entity, which child entities belong to the aggregate, and which external entities are referenced by ID only. Aggregate boundaries determine repository scope, transaction scope, and domain event emission points — leaving them implicit means the Engineer will make these decisions during implementation, which is not acceptable.

**Implementation rules:**

- **Only the aggregate root is loaded and saved through repositories** — there is one repository per aggregate, and it operates on the root only. Internal entities have no repository of their own.
- **Internal entities cannot be modified from outside the aggregate** — callers interact with the root, which delegates to its children. Direct access to internal entities bypasses invariant enforcement.
- **Cross-aggregate interactions must occur through services** — aggregates do not hold references to other aggregate roots. A service coordinates between aggregates; aggregates do not reach into each other.
- **Unidirectional relationships** — aggregate relationships must be unidirectional whenever possible. Bidirectional associations across aggregate boundaries are forbidden — they cause ORM cascade issues, unpredictable delete behaviour, and tight coupling between aggregates. Cross-aggregate references must use identifiers only, never object references.
- **Transactions must not span multiple aggregates** — if an operation needs to modify two aggregates atomically, this is a design signal: either the boundary is wrong, or eventual consistency should be used with a domain event.
- **Keep aggregates small** — aggregates must remain small enough to be loaded and modified within a single transaction without excessive memory or lock contention. Collections growing beyond a few hundred elements should trigger a boundary review — model oversized collections as separate aggregates coordinated through domain events or services. If in doubt, make the boundary smaller.

## Domain Events

Important domain state changes may emit domain events to decouple side effects from the core transaction. This keeps aggregates focused and avoids entangling unrelated concerns (e.g. sending an email, updating a read model, triggering a downstream flow) inside the aggregate itself.

**Spec requirement**: for every aggregate that emits domain events, define in the spec: event name (past tense, business language), emitting aggregate, triggering state transition, payload schema, and expected consumers. Events exposed outside the service boundary become part of the public integration contract and require an ADR for breaking changes. Internal domain events may evolve freely within the bounded context.

**Implementation rules:**

- Emit a domain event when a significant state transition occurs — `OrderCancelled`, `PaymentConfirmed`, `SeatReserved` — the name must reflect what happened in business language, not technical intent
- Domain events are facts — they describe what happened, past tense, and are immutable. They are never commands.
- Domain events must be immutable value objects — implement as `record` or final class with no setters. Event payloads must contain only primitive values and identifiers, never entity references. Entity references create hidden coupling and break safe serialisation across service boundaries.
- Domain events must be raised by the aggregate root that owns the state change — `order.cancel()` raises `OrderCancelled`, not the service. Services must not construct or invent domain events themselves.
- Domain events are raised inside the aggregate during the state change and stored on the aggregate (e.g. accumulated in a `List<DomainEvent>` field) — they are not published immediately
- The application service persists the aggregate first, then reads the accumulated events from it and publishes them only after the transaction successfully commits — events must never be published before persistence succeeds
- Domain events and their side effects (notifications, projections, downstream calls) must never be published or handled inside the active transaction — if the transaction rolls back, already-published events cannot be recalled. The spec must declare which publication approach applies per event type — this is not an implementation-time decision. Two permitted approaches:
  - **Transactional Outbox** (when message loss is not acceptable): persist the event in an outbox table within the same transaction as the aggregate state change; a background publisher reads and delivers it to the broker. The event is never lost even if the broker is unavailable at commit time.
  - **`@TransactionalEventListener(phase = AFTER_COMMIT)`** (when message loss is acceptable): dispatched after commit so rollbacks are safe, but silently lost if the broker is unavailable at that moment. Permitted for in-process side effects (e.g. cache invalidation, audit logging, projections) or cross-service calls where the spec explicitly accepts the loss risk.
- Event handlers must be idempotent — the same event may be delivered more than once
- Document which aggregates emit which events in the spec — event contracts must be defined before implementation begins. The Architect owns the contract definition; the Engineer owns the implementation.

## Domain Services

Domain services encapsulate domain logic that does not naturally belong to a single aggregate (e.g. pricing calculations involving multiple aggregates, domain-level validation requiring cross-aggregate state).

- Domain services live in the Domain layer
- They contain no infrastructure or persistence concerns
- Application services may depend on domain services. Domain services must never depend on application services.
- See `.claude/skills/clean-architecture/SKILL.md` for service-terminology and layer rules.

## Code Review Checklist — Domain Model

Apply during implementation review:

- Domain rules live in entities, not services — flag any service method implementing a rule that belongs to an entity
- State transitions occur through intention-revealing entity methods that enforce invariants — flag any direct field assignment from outside the entity
- Aggregate boundaries respected — internal entities not accessed directly, cross-aggregate interactions go through services only
- Services coordinate workflows; entities make domain decisions — a service that decides what "makes an order cancellable" is a design smell
- Domain events must be raised by the aggregate root that owns the state change and stored on the aggregate before publication — services must not construct or invent domain events themselves. The application service persists the aggregate first, then publishes the accumulated events only after the transaction commits.
- Aggregates must remain small enough to be loaded and modified within a single transaction without excessive memory or lock contention.
- Domain methods must not trigger lazy-loading side effects — aggregate invariants must be enforceable using only the state already loaded within the aggregate boundary.
- No public setters on aggregate roots for invariant-bearing fields
- Entity collections must never be exposed as mutable — aggregate roots must return read-only views or expose intention-revealing methods only
- Aggregate relationships must be unidirectional whenever possible — bidirectional associations across aggregate boundaries are forbidden. Cross-aggregate references must use identifiers only, never object references.

## Ubiquitous Language

The names used in code — classes, methods, events, fields — must match the names used by the business stakeholders. Translation between "what the user calls it" and "what the code calls it" is a source of defects and miscommunication.

- Event names are past tense, business language: `OrderCancelled`, not `OrderCancellationEvent` or `OrderUpdated`
- State transition methods name the business action: `order.cancel()`, not `order.setStatus(CANCELLED)`
- If the business renames a concept, the code must follow — silent terminology drift creates two domains, one in the code and one in conversation

## Anti-Patterns to Reject

- **Anemic Model** — entities with only getters/setters and no behaviour. Logic lives in services. Reject in review unless Transaction Script was explicitly chosen in the spec.
- **Generic Repository Per Entity** — one repository per aggregate root only. A repository on a child entity is a design violation.
- **Domain Events as Commands** — `SendEmailEvent`, `UpdateBalanceEvent`. Events are facts about what happened, not instructions about what to do next.
- **Service-Owned State Transitions** — a service that decides `if (order.status == PENDING && now > deadline) order.status = EXPIRED`. The rule belongs inside `Order`.
- **Lazy-Load Inside a Domain Method** — silently triggering an ORM lazy-load inside `order.cancel()`. The Application service must load all required state before invoking the method.

---

## Related Skills

- `clean-architecture` — DDD lives inside Clean Architecture's Domain layer; pair the two skills
- `jpa-relationships` — entity mapping, cross-aggregate references by ID only, cascade rules
- `jpa-fetching` — aggregate-internal vs cross-aggregate query strategies
- `async-consumers` — domain event publication mechanics and consumer-side idempotency
- `spring-boot-patterns` — Spring's `@TransactionalEventListener` and event publisher
