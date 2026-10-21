---
name: clean-architecture
description: Layered architecture and dependency direction rules. Use when designing service boundaries, reviewing dependency direction in a PR, deciding where transaction boundaries belong, or checking that domain objects are isolated from framework concerns.
---

# Clean Architecture

Answers the question **"Where does this code live, and which direction can it depend on?"** This skill is paradigm canon — stack-agnostic, reusable across agents and languages. For this project's specific package layouts and tooling choices, see `.claude/conventions/architecture-standards.md`.

## When to Use
- Designing service boundaries or layer responsibilities for a new feature
- Reviewing dependency direction in a PR — flagging layer violations as Blockers
- Deciding where transaction boundaries belong (always Application layer)
- Auditing whether domain objects depend on framework runtime components
- Confirming that external I/O does not occur inside a DB transaction

---

## Layered Architecture

Dependency direction is enforced strictly and without exception. Arrows point in the direction of *compile-time dependency* — each layer depends on what it points to.

```
API Layer (Controllers, DTOs)
    │ depends on
    ▼
Application Layer (Use Cases / Services — workflow, transactions, cross-aggregate coordination)
    │ depends on
    ▼
Domain Layer (Entities, Aggregates, Value Objects, Domain Events,
              Repository interfaces)
    ▲
    │ depends on (implements Repository interfaces defined in Domain)
    │
Persistence Layer (Repository implementations, Entity mappers)
```

The Domain layer is the centre — every other layer depends on it; it depends on nothing. This is the **Dependency Inversion** principle in action: the Persistence layer implements interfaces *owned by* the Domain, so at runtime the Application layer calls into Persistence through a Domain-owned abstraction, but at compile time Persistence is the one with the dependency arrow into Domain.

**Layer dependency rules:**
- The API layer may import from the Application layer only
- The Application layer may import from the Domain layer only
- The Persistence layer implements domain repository interfaces and depends on the Domain layer — it does not expose its own abstractions upward
- The Domain layer depends on nothing — no Spring beans, no JPA implementations, no HTTP clients (see `Domain Layer Isolation` below for the permitted-annotations exception)
- Violations are a hard Blocker — never a warning

## Transaction Boundaries

- Transaction boundaries are defined exclusively in the Application layer — controllers must never start transactions, domain objects must never depend on transaction state, and persistence implementations must not define transaction boundaries
- Each application service method represents a single transactional boundary unless explicitly documented otherwise in the spec
- Multiple transactions within one service method require explicit justification and documentation in the spec

## Service Terminology

- **Application services** (Application layer) — orchestrate use cases: load aggregates, invoke domain logic, persist, publish events. They contain no business rules.
- **Domain services** (Domain layer) — encapsulate domain logic that does not naturally belong to a single aggregate (e.g. pricing calculations involving multiple aggregates, domain-level validation requiring cross-aggregate state). They contain no infrastructure or persistence concerns.
- Application services may depend on domain services. Domain services must never depend on application services.

## Domain Layer Isolation

- The Domain layer contains business logic — entities decide, services coordinate
- **Domain object isolation** — domain objects (entities, aggregates, value objects) must not depend on framework runtime components. No Spring beans, repositories, HTTP clients, messaging clients, or dependency injection inside domain objects. Domain methods must not access repositories, services, or infrastructure components — persistence is accessed exclusively through domain repository interfaces, called from the Application layer.
- **Permitted persistence annotations** — persistence mapping annotations are allowed as a pragmatic exception to keep the domain model close to the data model. For the full permitted and forbidden list (JPA, Hibernate, Spring Data audit, `@EntityListeners`), see the **Permitted Annotations on Domain Objects** section in `.claude/skills/jpa-patterns/SKILL.md`.
- **Aggregate mutation path** — all mutations of an aggregate must occur through the aggregate root. Child entities must not be modified directly by services or repositories.

Business logic lives in the Domain layer — in entities and aggregates. The Application layer orchestrates workflows and delegates decisions to domain objects; it does not implement domain rules.

Cross-cutting concerns (logging, exceptions, config) are the only permitted horizontal dependencies.

## No External I/O Inside a DB Transaction

External calls (HTTP, SQS, Kafka, file storage, or any I/O outside the database) must never occur inside a database transaction — a slow or hanging external call holds a DB connection captive for its entire duration, causing connection exhaustion, deadlocks, and stuck transactions under load. External side effects must occur after the transaction commits or be triggered through domain events.

This is a non-negotiable safety rule — a spec that requires an external call inside a transaction must be escalated to the Architect before implementation.

## Repositories as Persistence Abstractions

- Repositories exist only for aggregate roots — never for internal entities
- Repositories are persistence abstractions only — no business rules, orchestration logic, or domain decisions inside repository methods
- Conditional logic or workflow behaviour in a repository is a design violation: move it to the domain or application layer
- Repository queries must load only a single aggregate root and its internal entities — never write a query that materialises multiple aggregates in one call
- Cross-aggregate data needs must be served by dedicated read-model queries (projections, query services, or database views) — never load multiple aggregate roots through a domain repository

## Explicitness

Hidden behaviour is forbidden — timeouts, retries, transactions, and caching must always be explicit in code or configuration. Never rely on framework defaults silently.

---

## Related Skills

- `domain-driven-design` — paired with Clean Architecture: this skill defines the layers; DDD defines what lives in the Domain layer
- `jpa-transactions` — transaction-boundary placement and proxy-bypass rules
- `spring-boot-patterns` — controller / service / repository patterns within the layers
- `caching-strategies` — caching wrappers live in the persistence / infrastructure layer
- `async-consumers` — external I/O and transaction-boundary rules for consumers
- `observability` — instrumentation is a cross-cutting concern, lives in Application / Infrastructure layers
