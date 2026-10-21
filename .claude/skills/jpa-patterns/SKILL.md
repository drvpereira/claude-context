---
name: jpa-patterns
description: Index of JPA/Hibernate skills. Lists the permitted annotations on domain objects and points to focused sub-skills for fetching, transactions, relationships, queries, and locking. Use as the entry point for any JPA topic.
---

# JPA Patterns — Index

JPA/Hibernate canon for this codebase. Use this file to navigate to the focused sub-skill that matches your task.

## When to Use
- Any JPA / Hibernate question — start here, follow the link to the focused sub-skill
- Reviewing JPA code in a PR — use the [Performance Checklist](#performance-checklist) below
- Designing a new entity — confirm which annotations are permitted on domain objects

---

## Sub-Skills

| Skill | When to use |
|---|---|
| [`jpa-fetching`](../jpa-fetching/SKILL.md) | N+1 queries, lazy loading, `LazyInitializationException`, FetchType design |
| [`jpa-transactions`](../jpa-transactions/SKILL.md) | `@Transactional` placement, propagation, read-only optimisation, proxy-bypass mistakes |
| [`jpa-relationships`](../jpa-relationships/SKILL.md) | `@OneToMany`, `@ManyToOne`, `@ManyToMany`, cascade behaviour, `equals`/`hashCode` for entities |
| [`jpa-queries`](../jpa-queries/SKILL.md) | Pagination, DTO projections, bulk DML, indexes |
| [`jpa-locking`](../jpa-locking/SKILL.md) | `@Version` optimistic locking, pessimistic locking, handling `OptimisticLockException` |

---

## Quick Reference: Common Problems

| Problem | Symptom | Skill |
|---|---|---|
| N+1 queries | Many SELECT statements | `jpa-fetching` |
| `LazyInitializationException` | Error outside transaction | `jpa-fetching` |
| Slow queries | Performance issues | `jpa-queries` |
| Missing transaction | Changes not persisted | `jpa-transactions` |
| Proxy bypass | `@Transactional` ignored from same class | `jpa-transactions` |
| Lost updates | Concurrent modifications | `jpa-locking` |
| Cascade misuse | Unintended deletes | `jpa-relationships` |

---

## Permitted Annotations on Domain Objects

Annotations allowed inside domain objects (entities, aggregates, value objects) as pragmatic persistence mapping exceptions. Domain logic must never depend on them.

**JPA mapping**
`@Entity`, `@Table`, `@Column`, `@Id`, `@GeneratedValue`, `@Embedded`, `@Embeddable`, `@OneToMany`, `@ManyToOne`, `@OneToOne`, `@JoinColumn`, `@Version`, `@Enumerated` — always specify `EnumType.STRING`; JPA defaults to `ORDINAL`, which silently corrupts data if enum values are reordered or new values are inserted before existing ones

**Hibernate extensions**
`@SQLDelete`, `@SQLRestriction` — soft deletes
`@Audited` — audit trail via Hibernate Envers

**Spring Data audit**
`@CreatedBy`, `@CreatedDate`, `@LastModifiedBy`, `@LastModifiedDate`

**`@EntityListeners`**
Permitted only when used exclusively with `AuditingEntityListener.class` for Spring Data auditing — no other listeners.

**Forbidden**
`@Transactional`, `@PrePersist`, `@PostLoad`, `@PostUpdate`, `@PreRemove`, and any custom `@EntityListeners` — these introduce hidden runtime behaviour or business logic inside the domain object, violating domain isolation.

For why domain objects must remain framework-isolated, see `.claude/skills/clean-architecture/SKILL.md`.

---

## Performance Checklist

When reviewing JPA code, check:

- [ ] No N+1 queries (use JOIN FETCH or @EntityGraph) — see `jpa-fetching`
- [ ] LAZY fetch by default (especially @ManyToOne) — see `jpa-fetching`
- [ ] Pagination for large result sets — see `jpa-queries`
- [ ] DTO projections for read-only queries — see `jpa-queries`
- [ ] Bulk operations for batch updates/deletes — see `jpa-queries`
- [ ] `@Version` on every mutable entity — see `jpa-locking`
- [ ] Indexes on frequently queried columns — see `jpa-queries`
- [ ] No lazy fields in toString() — see `jpa-fetching`
- [ ] Read-only transactions where applicable — see `jpa-transactions`
- [ ] No `@Transactional` on repository methods — see `jpa-transactions`
- [ ] No `@Transactional` method called from within the same class — see `jpa-transactions`

---

## Related Skills

- `spring-boot-patterns` — Spring Boot controller/service patterns
- `java-code-review` — General code review checklist
- `clean-architecture` — Layered architecture, transaction-boundary placement, domain isolation
- `domain-driven-design` — Aggregate boundaries, why cross-aggregate references must be by ID
