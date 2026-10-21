---
name: jpa-locking
description: JPA optimistic locking with @Version, pessimistic locking, and handling OptimisticLockException. Use when implementing or reviewing state-machine transitions, concurrent modifications, or designing concurrency strategy for mutable entities.
---

# JPA Locking

Covers optimistic locking (the default), pessimistic locking (high-contention exception), and how to handle `OptimisticLockException`. For broader JPA context, see `.claude/skills/jpa-patterns/SKILL.md`.

## When to Use
- Designing concurrency strategy for a mutable entity
- Implementing state-machine transitions (`PENDING → PROCESSING`)
- Handling concurrent updates from multiple users or processes
- Reviewing whether `@Version` is on every mutable entity

---

## Optimistic Locking — Default

```java
// ✅ GOOD: Use @Version for optimistic locking
@Entity
public class Order {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Version
    private Long version;

    private OrderStatus status;
    private BigDecimal total;
}

// When two users update same order:
// User 1: loads order (version=1), modifies, saves → version becomes 2
// User 2: loads order (version=1), modifies, saves → OptimisticLockException!
```

**Rules:**
- Optimistic locking is the default — low contention, no DB-level blocking, scales horizontally
- Use `@Version` on every mutable entity — aggregate roots and child entities alike. The aggregate root's `@Version` does not protect child entities from direct JPQL bulk updates or native queries that bypass the root.
- Exception: lookup tables, reference data, and append-only entities where concurrent modification is not possible do not require `@Version`; justify the absence in a code comment.
- Never rely on application-level checks alone for uniqueness or state transitions — a check followed by a write is a race condition. Use DB unique constraints or version guards.
- Protect every state machine transition (e.g. `PENDING → PROCESSING`) with a version check or conditional update — never read-then-write without a guard.

---

## Pessimistic Locking — Narrow Exception

```java
// ✅ GOOD: PESSIMISTIC_WRITE for high-contention state transitions
public interface SeatRepository extends JpaRepository<Seat, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT s FROM Seat s WHERE s.id = :id")
    Optional<Seat> findByIdForUpdate(@Param("id") Long id);
}
```

**Rules:**
- Pessimistic locking (`PESSIMISTIC_WRITE`) is reserved for high-contention state transitions where conflicts are frequent and retrying is expensive — justify in code and in the spec
- Locks held across slow operations or external I/O exhaust DB connections — keep transactions short

---

## Handling OptimisticLockException

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final OrderMapper orderMapper;

    @Transactional
    public OrderDTO updateOrder(Long id, UpdateOrderRequest request) {
        try {
            Order order = orderRepository.findById(id).orElseThrow();
            order.updateStatus(request.status());  // intention-revealing method, not a setter
            return orderMapper.toResponse(order);  // map to DTO — never return entity from service
        } catch (OptimisticLockException e) {
            throw new ConcurrentModificationException(
                "Order was modified by another user. Please refresh and try again."
            );
        }
    }

    // Or with retry
    // Requires: spring-retry on the classpath + @EnableRetry on a @Configuration class
    @Retryable(value = OptimisticLockException.class, maxAttempts = 3)
    @Transactional
    public OrderDTO updateOrderWithRetry(Long id, UpdateOrderRequest request) {
        Order order = orderRepository.findById(id).orElseThrow();
        order.updateStatus(request.status());  // intention-revealing method, not a setter
        return orderMapper.toResponse(order);  // map to DTO — never return entity from service
    }
}
```

**Handling rules** — handle `OptimisticLockException` explicitly using one of:
- **Automatic retry with exponential backoff** — when the operation is idempotent and retrying is safe
- **Return `409 Conflict` to the client** — when the caller should resolve the conflict
- **Surface a domain-specific concurrency error with a meaningful message** — when the conflict has business significance

Never return a generic `500` — an unhandled `OptimisticLockException` is a silent correctness failure, not an unexpected system error.

---

## Document the Concurrency Model

For any shared mutable state, the spec must declare the concurrency model — optimistic (default), pessimistic (justified), or conflict-free (append-only / immutable). "It'll be fine" is not a strategy.

See `conventions/architecture-standards.md` Data Consistency section for the spec-level requirements.

---

## Related Skills

- `jpa-patterns` — index of all JPA skills
- `jpa-transactions` — `@Transactional` placement, propagation, common mistakes
- `idempotency` — when retrying a write is safe
