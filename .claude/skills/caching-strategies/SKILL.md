---
name: caching-strategies
description: Caching patterns for Spring / JVM applications — cache-aside, cached repository, cached gateway, when to use `@Cacheable`, invalidation, key composition, TTL, PII restrictions, and graceful degradation. Use when designing or reviewing cache usage in a service.
---

# Caching Strategies

How to add caching without compromising correctness. Correctness mistakes around caching (stale data, transaction-rollback divergence, proxy bypass) cause silent production bugs that take weeks to diagnose. Read this skill *before* introducing a cache, not after a performance problem forces one.

## When to Use
- Designing the spec for an endpoint or aggregate where caching is being proposed
- Reviewing code that introduces `@Cacheable`, `@CacheEvict`, or a custom cached gateway / repository
- Diagnosing stale-data bugs, cache-coherency issues, or post-rollback inconsistency
- Deciding whether to use annotation-based caching or a cached-wrapper pattern

---

## Pattern Selection

| Pattern | When to use | Notes |
|---|---|---|
| **Cached repository / cached gateway** | Domain repositories, external service gateways | Preferred default — caching lives in persistence/infrastructure layer, satisfies the same domain interface, unit-testable in isolation |
| **`@Cacheable` / `@CacheEvict`** | Simple cross-cutting cases: reference data, lookup tables, configuration | Only when no conditional logic and default key strategy is sufficient |
| **Cache-aside (manual)** | Custom flows where you control population and invalidation | Acceptable when the wrapper pattern is overkill |
| **ORM-level transparent caching (Hibernate second-level)** | **Forbidden** | Silent caching with hard-to-reason-about staleness and invalidation behaviour |

---

## Cached Repository / Cached Gateway

Implement a caching wrapper that satisfies the same domain interface as the underlying component.

```java
// Domain interface — owned by the Domain layer
public interface ProductRepository {
    Optional<Product> findById(ProductId id);
}

// Persistence implementation (the real one)
@Repository
@RequiredArgsConstructor
class JpaProductRepository implements ProductRepository {
    private final EntityManager em;

    @Override
    public Optional<Product> findById(ProductId id) {
        return Optional.ofNullable(em.find(ProductEntity.class, id.value()))
            .map(ProductMapper::toDomain);
    }
}

// Cached wrapper — also implements the domain interface
@Repository
@Primary
@RequiredArgsConstructor
class CachedProductRepository implements ProductRepository {

    private final JpaProductRepository delegate;
    private final Cache<ProductId, Product> cache;  // e.g. Caffeine

    @Override
    public Optional<Product> findById(ProductId id) {
        Product cached = cache.getIfPresent(id);
        if (cached != null) return Optional.of(cached);
        Optional<Product> result = delegate.findById(id);
        result.ifPresent(p -> cache.put(id, p));
        return result;
    }
}
```

**Why this is preferred:**
- Caching concern lives in persistence/infrastructure — Domain and Application layers are unaware
- The cached wrapper is unit-testable independently of the database
- No annotation proxy magic — explicit code path, easy to reason about
- Cache invalidation can be conditional, composite, or asynchronous

---

## `@Cacheable` / `@CacheEvict`

Acceptable for simple cross-cutting cases — reference data, lookup tables, configuration — where the default key strategy is sufficient and no conditional logic is needed.

```java
@Service
@RequiredArgsConstructor
public class CountryService {

    private final CountryRepository repository;

    @Cacheable(value = "countries", key = "#code")
    public Optional<Country> findByCode(String code) {
        return repository.findByCode(code);
    }

    @CacheEvict(value = "countries", allEntries = true)
    public void refreshCountries() {
        // triggered by admin or scheduled job
    }
}
```

**Proxy bypass rule (same as `@Transactional`):** `@Cacheable` / `@CacheEvict` are AOP-proxy-based. Calling a cached method from another method in the same class bypasses the proxy, and the cache is never consulted or invalidated. Extract to a separate bean if you need internal calls to hit the cache.

---

## Cache Invalidation

- **Tie invalidation to write operations** — evict or update the cache entry immediately after the transaction commits
- **Never perform cache operations inside the DB transaction** — external caches (Redis, Memcached) are not part of the transaction and cannot be rolled back. If the transaction rolls back, the cache and DB are out of sync.
- Use `@TransactionalEventListener(phase = AFTER_COMMIT)` or an explicit `TransactionSynchronizationManager.registerSynchronization` callback to evict only after commit
- Avoid `@CacheEvict` directly on `@Transactional` methods if the transaction can fail — the eviction happens even on rollback

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final ApplicationEventPublisher events;

    @Transactional
    public OrderDTO updateStatus(Long orderId, OrderStatus newStatus) {
        Order order = orderRepository.findById(orderId).orElseThrow();
        order.transitionTo(newStatus);  // raises OrderStatusChanged event
        events.publishEvent(new OrderStatusChanged(orderId));
        return orderMapper.toResponse(order);
    }
}

@Component
@RequiredArgsConstructor
class OrderCacheInvalidator {

    private final CacheManager cacheManager;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void evictOnStatusChange(OrderStatusChanged event) {
        cacheManager.getCache("orders").evict(event.orderId());
    }
}
```

---

## Cache Keys

- **Include every discriminator that affects the cached value** — entity ID, version, tenant ID, locale, currency, feature-flag state
- A cache key that omits a discriminator silently returns the wrong value to the wrong caller
- For tenant-isolated systems, the tenant ID is mandatory — a missing tenant in the key is a cross-tenant data leak

```java
// ❌ BAD: missing tenant — cross-tenant leak risk
@Cacheable(value = "products", key = "#id")
Product findById(String id);

// ✅ GOOD: tenant in the key
@Cacheable(value = "products", key = "#tenantId + ':' + #id")
Product findById(String tenantId, String id);
```

---

## TTL Requirements

- **Never cache mutable entities without a TTL** — unbounded cache entries become stale silently
- Define TTL in the spec, not in code comments — TTL is a product / consistency decision, not an implementation detail
- For long-lived TTLs (>5 minutes on mutable data), implement explicit invalidation on write paths

---

## PII and Sensitive Data

- **Never cache PII or sensitive data without explicit security review** — cache stores (Redis, Memcached, in-process Caffeine) often have weaker access controls than the primary database
- If caching is required for sensitive data, encrypt at rest, restrict network access, audit log access, and document the decision in an ADR
- Tokens, passwords, payment data, and personally identifiable information must never reach a cache without sign-off

---

## Graceful Degradation

- **Cache failures must degrade gracefully** — a cache miss or cache unavailability must fall through to the source, never fail the request
- Treat cache outages as expected: timeouts on Redis must not cascade into request failures
- Set short timeouts on cache calls (e.g. 50–100ms) — never the framework default
- Circuit-break the cache layer for sustained failures — fall through to DB until the cache is healthy

---

## Anti-Patterns

- **ORM second-level cache** (Hibernate L2) — forbidden. Hidden runtime behaviour, hard to invalidate, deeply coupled to the ORM.
- **Caching inside a transaction** — cache write happens regardless of rollback; DB and cache diverge silently.
- **No TTL on mutable data** — guarantees stale data eventually.
- **Cache key missing tenant or locale discriminator** — cross-tenant or localised-content leak.
- **`@Cacheable` method called from same class** — proxy bypass; cache never hit (same issue as `@Transactional`).

---

## Related Skills

- `clean-architecture` — caching belongs in persistence / infrastructure layer, not in Domain or Application
- `jpa-transactions` — same proxy-bypass rule applies to `@Transactional`
- `domain-driven-design` — cached repositories implement Domain-owned interfaces
- `spring-boot-patterns` — `@Cacheable` annotations, Spring's `CacheManager` configuration
- `security-audit` — review before caching any sensitive data
