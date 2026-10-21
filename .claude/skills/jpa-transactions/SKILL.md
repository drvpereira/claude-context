---
name: jpa-transactions
description: JPA/Spring transaction management — @Transactional placement, propagation, read-only optimisations, common mistakes (proxy bypass, transaction on repositories). Use when designing transaction boundaries, debugging missing transactions, or reviewing @Transactional placement.
---

# JPA Transactions

Covers `@Transactional` usage in Spring services, propagation modes, and common mistakes. For broader JPA context, see `.claude/skills/jpa-patterns/SKILL.md`. For layered architecture rules on transaction-boundary placement, see `.claude/skills/clean-architecture/SKILL.md`.

## When to Use
- Designing transaction boundaries for a new service method
- Debugging "transaction not started" or proxy-bypass issues
- Choosing propagation mode (`REQUIRED`, `REQUIRES_NEW`, `MANDATORY`)
- Reviewing `@Transactional` placement in code review

---

## Basic Transaction Management

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final OrderMapper orderMapper;

    // Read-only: Optimized, no dirty checking
    @Transactional(readOnly = true)
    public OrderDTO findById(Long id) {
        return orderRepository.findById(id)
            .map(orderMapper::toResponse)  // map to DTO — never return entity from service
            .orElseThrow();
    }

    // Write: Full transaction with dirty checking
    @Transactional
    public OrderDTO createOrder(CreateOrderRequest request) {
        // Use a constructor or factory method — never new Order() followed by setters
        Order order = Order.create(request.customerId(), request.items());
        Order saved = orderRepository.save(order);
        return orderMapper.toResponse(saved);  // map to DTO — never return entity from service
    }

    // Explicit rollback
    @Transactional(rollbackFor = Exception.class)
    public void processPayment(Long orderId) throws PaymentException {
        // Rolls back on any exception, not just RuntimeException
    }
}
```

---

## Transaction Propagation

> Examples below are simplified to focus on propagation semantics. Services communicate via IDs — never entity references.

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final PaymentService paymentService;

    @Transactional
    public void placeOrder(Long orderId) {
        // REQUIRED (default): joins existing transaction or creates a new one
        paymentService.processPayment(orderId);

        // If paymentService throws, entire operation is rolled back
    }
}

@Service
public class PaymentService {

    // REQUIRES_NEW: Always creates a new transaction
    // If this fails, the caller's transaction can still commit independently
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void processPayment(Long orderId) {
        // Independent transaction
    }

    // MANDATORY: Must run within an existing transaction
    @Transactional(propagation = Propagation.MANDATORY)
    public void updatePaymentStatus(Long orderId) {
        // Throws TransactionRequiredException if no active transaction
    }
}
```

---

## Repository Methods Must Not Declare @Transactional

Transaction boundaries belong to the service layer. Repository methods must never declare `@Transactional` — they participate in the caller's transaction via propagation.

```java
// ❌ BAD: Transaction boundary defined in repository
public interface OrderRepository extends JpaRepository<Order, Long> {
    @Transactional  // Not here — the service owns the boundary
    Optional<Order> findByIdWithItems(Long id);
}

// ✅ GOOD: Transaction boundary in the service
@Service
public class OrderService {
    @Transactional(readOnly = true)
    public OrderDTO getOrder(Long id) {
        return orderRepository.findByIdWithItems(id)  // joins the service transaction
            .map(orderMapper::toResponse)
            .orElseThrow();
    }
}
```

Exception: Spring Data JPA's built-in methods (`save`, `findById`, `delete`, etc.) carry their own `@Transactional` internally — this is correct and expected. The rule applies only to methods you declare.

---

## Common Transaction Mistakes

```java
// ❌ BAD: Calling @Transactional method from same class
@Service
public class OrderService {

    public void processOrder(Long id) {
        updateOrder(id);  // @Transactional is IGNORED!
    }

    @Transactional
    public void updateOrder(Long id) {
        // Transaction not started because called internally
    }
}

// ✅ GOOD: Extract to a separate service — proxy is bypassed when calling from within the same class
@Service
@RequiredArgsConstructor
public class OrderWorkflowService {

    private final OrderCommandService orderCommandService;

    public void processOrder(Long id) {
        orderCommandService.updateOrder(id);  // Transaction works — separate bean
    }
}

@Service
public class OrderCommandService {

    @Transactional
    public void updateOrder(Long id) {
        // Transaction properly started
    }
}
```

---

## Rules Summary

- Declare `@Transactional` explicitly per method — never at class level. Class-level `readOnly = true` is dangerous: a write method added later without an override silently operates without a proper transaction.
- Read methods: `@Transactional(readOnly = true)`. Write methods: `@Transactional`.
- Repository methods must never declare `@Transactional`.
- Never call a `@Transactional` method from within the same class — Spring's proxy is bypassed, the transaction will not start.
- `rollbackFor = Exception.class` on write methods that throw checked exceptions — Spring only rolls back unchecked by default.
- External calls (HTTP, SQS, Kafka, file storage) must never occur inside a DB transaction — see `clean-architecture` skill.

---

## Related Skills

- `jpa-patterns` — index of all JPA skills
- `clean-architecture` — layered architecture, transaction-boundary placement, framework isolation
- `jpa-locking` — optimistic locking, handling `OptimisticLockException`
