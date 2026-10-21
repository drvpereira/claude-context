---
name: idempotency
description: Idempotency implementation patterns for REST endpoints. Use when implementing any state-changing endpoint (POST, PUT, PATCH) — idempotency key, natural uniqueness, upsert, and conditional update patterns.
---

# Idempotency

All state-changing endpoints (POST, PUT, PATCH) must be idempotent — identical requests must produce the same result regardless of how many times they are sent. This is essential for safe retries from clients, load balancers, and circuit breakers.

The implementation approach is defined in the spec. If the spec does not define a strategy, raise it to the Lead Architect before implementing — not after.

GET and HEAD are idempotent by nature — no key required.

DELETE must also be idempotent — a second call on an already-deleted resource must return `404` or `204`, never `500`. No idempotency key is needed; the natural state of the resource provides the deduplication.

---

## Implementation Patterns

### Idempotency Key

Accept an `Idempotency-Key` header (client-generated UUID per logical operation). Store key + response for the deduplication window (default: 24h). Return the original response on duplicate — do not re-execute.

**Rule:** key storage must be part of the same transaction as the operation. Storing the key after the operation produces a race condition where a crash between the two leaves the operation re-executable.

```java
// Check for duplicate before executing
Optional<IdempotencyRecord> existing = idempotencyStore.find(idempotencyKey);
if (existing.isPresent()) {
    return existing.get().getStoredResponse();  // return original response with original status code
}
// Execute operation and store key + response atomically
```

**Response code on cache hit:** return the same status code as the original response — e.g. `201 Created` again, not `200 OK`. Returning a different status on a duplicate breaks client retry logic that checks the status to confirm the operation succeeded.

### Natural Uniqueness

Unique constraint in the DB prevents duplicate records. The operation attempts to insert and relies on the constraint to reject duplicates.

```java
// Unique constraint on (orderId, productId) — second insert throws DataIntegrityViolationException
// Catch and return the original result, not an error
```

### Upsert Semantics

Insert or update based on business identity, not technical ID. The second call produces the same final state as the first.

```java
// INSERT ... ON CONFLICT (business_key) DO UPDATE SET ...
// or: findByBusinessKey().orElse(new Entity()) → save
```

### Conditional Update

Check a precondition (e.g. version or status) before applying the change. A duplicate request fails the precondition check because the state has already advanced.

```java
// Guard checks precondition — idempotency lives here, not in cancel()
if (order.getStatus() == OrderStatus.CANCELLED) {
    return; // already cancelled — no-op, do not call cancel() again
}
order.cancel(); // only reached when status is PENDING; throws on any other invalid transition → caller receives 422, not 500
```

---

## Testing Idempotency

Every idempotency strategy must have at least two tests:

1. **Duplicate request returns the same response** — call the operation twice with the same key or same business identity; assert the response body and status code are identical on both calls
2. **Duplicate request does not produce a second side effect** — assert the DB record count, downstream call count (via mock verify), or event count did not increase on the second call

```java
@Test
@DisplayName("duplicate order submission with the same idempotency key returns original response without creating a second order")
void duplicateSubmissionReturnsCachedResponse() {
    String idempotencyKey = UUID.randomUUID().toString();

    OrderResponse first = orderService.submit(request, idempotencyKey);
    OrderResponse second = orderService.submit(request, idempotencyKey);

    assertThat(second).isEqualTo(first);
    assertThat(orderRepository.countByCustomerId(request.customerId())).isEqualTo(1);
}
```

---

## Non-Idempotent Operations

Flag in Phase 1 if any operation cannot be made idempotent (e.g. external side effects that cannot be deduplicated — charging a payment processor, sending an SMS). This is an architectural risk requiring explicit user acceptance and must be documented in the spec.

---

## Async Consumers

Async consumer idempotency follows different rules — see the `async-consumers` skill.

---

## Related Skills

- `async-consumers` — SQS consumer idempotency via DB unique constraint and ON_SUCCESS acknowledgement
- `http-semantics` — HTTP method contracts and DELETE idempotency requirements
- `java-code-review` — General review checklist including duplicate-handling and exception safety
