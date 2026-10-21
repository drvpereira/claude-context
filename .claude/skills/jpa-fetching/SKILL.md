---
name: jpa-fetching
description: JPA fetch strategies — preventing N+1 queries, lazy loading, FetchType defaults, and resolving LazyInitializationException. Use when many SELECT statements are issued, LazyInitializationException is thrown, or when designing fetch strategy for entity associations.
---

# JPA Fetching

Covers the #1 JPA performance killer (N+1 queries), lazy loading mechanics, and how to resolve `LazyInitializationException`. For broader JPA context, see `.claude/skills/jpa-patterns/SKILL.md`.

## When to Use
- User mentions "N+1 problem" / "too many queries"
- `LazyInitializationException` errors
- Questions about fetch strategies (EAGER vs LAZY)
- Designing or reviewing entity association fetch behaviour

---

## N+1 Problem

> The #1 JPA performance killer

### The Problem

```java
// ❌ BAD: N+1 queries
@Entity
public class Author {
    @Id private Long id;
    private String name;

    @OneToMany(mappedBy = "author", fetch = FetchType.LAZY)
    private List<Book> books;
}

// This innocent code...
List<Author> authors = authorRepository.findAll();  // 1 query
for (Author author : authors) {
    System.out.println(author.getBooks().size());   // N queries!
}
// Result: 1 + N queries (if 100 authors = 101 queries)
```

### Solution 1: JOIN FETCH (JPQL)

```java
// ✅ GOOD: Single query with JOIN FETCH
public interface AuthorRepository extends JpaRepository<Author, Long> {

    @Query("SELECT a FROM Author a JOIN FETCH a.books")
    List<Author> findAllWithBooks();
}

// Usage - single query
List<Author> authors = authorRepository.findAllWithBooks();
```

### Solution 2: @EntityGraph

```java
// ✅ GOOD: EntityGraph for declarative fetching
public interface AuthorRepository extends JpaRepository<Author, Long> {

    @EntityGraph(attributePaths = {"books"})
    List<Author> findAll();

    // Or with named graph
    @EntityGraph(value = "Author.withBooks")
    List<Author> findAllWithBooks();
}

// Define named graph on entity
@Entity
@NamedEntityGraph(
    name = "Author.withBooks",
    attributeNodes = @NamedAttributeNode("books")
)
public class Author {
    // ...
}
```

### Solution 3: Batch Fetching

```java
// ✅ GOOD: Batch fetching (Hibernate-specific)
@Entity
public class Author {

    @OneToMany(mappedBy = "author")
    @BatchSize(size = 25)  // Fetch 25 at a time
    private List<Book> books;
}

// Or globally in application.properties
spring.jpa.properties.hibernate.default_batch_fetch_size=25
```

### Detecting N+1

```yaml
# Enable SQL logging to detect N+1
spring:
  jpa:
    show-sql: true
    properties:
      hibernate:
        format_sql: true

logging:
  level:
    org.hibernate.SQL: DEBUG
    org.hibernate.type.descriptor.sql.BasicBinder: TRACE
```

**CI enforcement — query count assertions:**

Use Hibernate statistics or a library such as `datasource-assert` / `sql-unit` to assert exact query counts in tests. This catches N+1 regressions automatically.

```java
// Example using datasource-proxy + AssertJ in a @DataJpaTest
@Test
void findAllWithBooks_issuesSingleQuery() {
    // given — seed data in place

    // when
    QueryCountHolder.clear();
    authorRepository.findAllWithBooks();

    // then
    assertThat(QueryCountHolder.getGrandTotal().getSelect()).isEqualTo(1);
}
```

Add at least one query-count assertion per repository method that uses JOIN FETCH or `@EntityGraph` — this is the only reliable way to prevent silent N+1 regressions in CI.

---

## Lazy Loading

### FetchType Basics

```java
@Entity
public class Order {

    // LAZY: Load only when accessed (default for collections)
    @OneToMany(mappedBy = "order", fetch = FetchType.LAZY)
    private List<OrderItem> items;

    // EAGER: Always load immediately (default for @ManyToOne, @OneToOne)
    @ManyToOne(fetch = FetchType.EAGER)  // ⚠️ Usually bad
    private Customer customer;
}
```

### Best Practice: Default to LAZY

```java
// ✅ GOOD: Always use LAZY, fetch when needed
@Entity
public class Order {

    @ManyToOne(fetch = FetchType.LAZY)  // Override EAGER default
    private Customer customer;

    @OneToMany(mappedBy = "order", fetch = FetchType.LAZY)
    private List<OrderItem> items;
}
```

### LazyInitializationException

```java
// ❌ BAD: Accessing lazy field outside transaction
@Service
public class OrderService {

    public Order getOrder(Long id) {
        return orderRepository.findById(id).orElseThrow();
    }
}

// In controller (no transaction)
Order order = orderService.getOrder(1L);
order.getItems().size();  // 💥 LazyInitializationException!
```

### Solutions for LazyInitializationException

> Service methods below are simplified to focus on lazy-loading mechanics. Production service methods must map entities to DTOs via mapper before returning — never return entities from service methods.

**Solution 1: JOIN FETCH in query**
```java
// ✅ Fetch needed associations in query
@Query("SELECT o FROM Order o JOIN FETCH o.items WHERE o.id = :id")
Optional<Order> findByIdWithItems(@Param("id") Long id);
```

**Solution 2: @Transactional on service method**
```java
// ✅ Keep transaction open while accessing
@Service
public class OrderService {

    @Transactional(readOnly = true)
    public OrderDTO getOrderWithItems(Long id) {
        Order order = orderRepository.findById(id).orElseThrow();
        // Access within transaction — map to primitive values, never pass entity to DTO
        int itemCount = order.getItems().size();
        return new OrderDTO(order.getId(), order.getStatus().name(), itemCount);
    }
}
```

**Solution 3: DTO Projection (recommended)**
```java
// ✅ BEST: Return only what you need
public interface OrderSummary {
    Long getId();
    String getStatus();
    int getItemCount();
}

@Query("SELECT o.id as id, o.status as status, SIZE(o.items) as itemCount " +
       "FROM Order o WHERE o.id = :id")
Optional<OrderSummary> findOrderSummary(@Param("id") Long id);
```

**Solution 4: Open Session in View (not recommended)**
```yaml
# Keeps session open during view rendering — disabled by default in Spring Boot 3
# ⚠️ Masks N+1 problems; do not enable. Solve the root cause instead.
spring:
  jpa:
    open-in-view: false  # Keep disabled (Spring Boot 3 default)
```

---

## toString() with Lazy Fields

```java
// ❌ BAD: toString includes lazy collection
@Entity
public class Author {
    @OneToMany(mappedBy = "author", fetch = FetchType.LAZY)
    private List<Book> books;

    @Override
    public String toString() {
        return "Author{id=" + id + ", books=" + books + "}";  // Triggers lazy load!
    }
}

// ✅ GOOD: Exclude lazy fields from toString
@Override
public String toString() {
    return "Author{id=" + id + ", name='" + name + "'}";
}
```

---

## Related Skills

- `jpa-patterns` — index of all JPA skills
- `jpa-queries` — pagination, DTO projections, bulk operations
- `jpa-relationships` — entity relationships, cascade behaviour
