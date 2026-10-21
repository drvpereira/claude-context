---
name: jpa-queries
description: JPA query optimisation — pagination, DTO projections, bulk operations, indexes. Use when designing queries for read-heavy paths, implementing pagination, or batching updates/deletes.
---

# JPA Queries

Covers query optimisation patterns: pagination, DTO projections, bulk DML, and indexing. For broader JPA context, see `.claude/skills/jpa-patterns/SKILL.md`. For preventing N+1 queries, see `.claude/skills/jpa-fetching/SKILL.md`.

## When to Use
- Designing a list endpoint (always paginated — see `architecture-standards.md`)
- Read-only queries that don't need full entity hydration
- Batch update or delete operations
- Adding or reviewing indexes for query patterns

---

## Pagination

```java
// ✅ GOOD: Always paginate large result sets
public interface OrderRepository extends JpaRepository<Order, Long> {

    Page<Order> findByStatus(OrderStatus status, Pageable pageable);

    // With sorting
    @Query("SELECT o FROM Order o WHERE o.status = :status")
    Page<Order> findByStatusSorted(
        @Param("status") OrderStatus status,
        Pageable pageable
    );
}

// Usage
Pageable pageable = PageRequest.of(0, 20, Sort.by("createdAt").descending());
Page<Order> orders = orderRepository.findByStatus(OrderStatus.PENDING, pageable);
```

**Rules:**
- Every list/fetch endpoint must have pagination from first implementation
- Default page size 50, maximum 100 — enforced at the API layer (see `.claude/conventions/architecture-standards.md`)
- Always paginate at DB level — never load a full result set into memory and slice in code

---

## DTO Projections

```java
// ✅ GOOD: Fetch only needed columns

// Interface-based projection
public interface OrderSummary {
    Long getId();
    String getCustomerName();
    BigDecimal getTotal();
}

@Query("SELECT o.id as id, o.customer.name as customerName, o.total as total " +
       "FROM Order o WHERE o.status = :status")
List<OrderSummary> findOrderSummaries(@Param("status") OrderStatus status);

// Class-based projection (DTO)
public record OrderDTO(Long id, String customerName, BigDecimal total) {}

@Query("SELECT new com.example.dto.OrderDTO(o.id, o.customer.name, o.total) " +
       "FROM Order o WHERE o.status = :status")
List<OrderDTO> findOrderDTOs(@Param("status") OrderStatus status);
```

**When to use DTO projections:**
- Read-only operations that don't need the full entity
- Cross-aggregate queries (a single domain repository must never load multiple aggregate roots — use a projection or a dedicated query service instead; see `.claude/conventions/architecture-standards.md` Read Models)
- High-volume queries where the cost of full entity hydration matters

---

## Bulk Operations

```java
// ✅ GOOD: Bulk update instead of loading entities
public interface OrderRepository extends JpaRepository<Order, Long> {

    // clearAutomatically = true: clears the persistence context after the DML — prevents stale cached entities in subsequent queries
    // flushAutomatically = true: flushes pending changes before executing the DML — prevents missed updates when dirty entities are in the context
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("UPDATE Order o SET o.status = :status WHERE o.createdAt < :date")
    int updateOldOrdersStatus(
        @Param("status") OrderStatus status,
        @Param("date") Instant date
    );

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("DELETE FROM Order o WHERE o.status = :status AND o.createdAt < :date")
    int deleteOldOrders(
        @Param("status") OrderStatus status,
        @Param("date") Instant date
    );
}

// Usage — inject Clock for testability, never call Instant.now() directly in service logic
@Transactional
public void archiveOldOrders() {
    Instant threshold = clock.instant().minus(365, ChronoUnit.DAYS);
    int updated = orderRepository.updateOldOrdersStatus(
        OrderStatus.ARCHIVED,
        threshold
    );
    log.info("Archived {} orders", updated);
}
```

**Rules:**
- Batch DB writes using `saveAll()` or bulk JPQL/native queries — never issue individual inserts or updates inside a loop
- Set `clearAutomatically = true` and `flushAutomatically = true` on `@Modifying` queries to avoid persistence-context staleness
- Bulk DML bypasses optimistic locking (no `@Version` check) — if the entities require version guarantees, load and save them individually instead

---

## Indexes

```java
// ❌ BAD: Frequent queries on non-indexed column
@Query("SELECT o FROM Order o WHERE o.customerEmail = :email")
List<Order> findByCustomerEmail(@Param("email") String email);

// ✅ GOOD: Add index
@Entity
@Table(indexes = @Index(name = "idx_order_customer_email", columnList = "customerEmail"))
public class Order {
    private String customerEmail;
}
```

**Rules:**
- Any new query pattern (`findByX`, `findByXAndY`) requires a corresponding index defined in a migration
- Index columns used in `WHERE`, `JOIN`, and `ORDER BY` clauses
- Composite indexes when multiple columns are queried together — order matters (leftmost prefix rule)
- Review write-performance impact when adding indexes to high-write tables

---

## Related Skills

- `jpa-patterns` — index of all JPA skills
- `jpa-fetching` — preventing N+1, JOIN FETCH, @EntityGraph
- `jpa-locking` — optimistic locking (note: bulk DML bypasses `@Version`)
