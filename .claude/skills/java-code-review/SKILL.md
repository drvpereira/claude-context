---
name: java-code-review
description: Systematic code review for Java with null safety, exception handling, concurrency, and performance checks. Use when user says "review code", "check this PR", "code review", or before merging changes.
---

# Java Code Review Skill

Systematic code review checklist for Java projects.

## When to Use
- User says "review this code" / "check this PR" / "code review"
- Before merging a PR
- After implementing a feature

## Review Strategy

1. **Quick scan** - Understand intent, identify scope
2. **Checklist pass** - Go through each category below
3. **Summary** - List findings by severity (Critical → Low)

## Output Format

```markdown
## Code Review: [file/feature name]

### Critical
- [Security vulnerability, data loss risk, production crash]

### High
- [Bug likely, significant performance issue, breaks API contract]

### Medium
- [Code smell, maintainability issue, missing best practice]

### Low / Style
- [Nitpicks, optional improvements]

### Good Practices Observed
- [Positive feedback — important for morale]
```

---

## Review Checklist

### 1. Null Safety

**Check for:**
```java
// ❌ NPE risk
String name = user.getName().toUpperCase();

// ✅ Safe
String name = Optional.ofNullable(user.getName())
    .map(String::toUpperCase)
    .orElse("");

// ✅ Also safe (early return)
if (user.getName() == null) {
    return "";
}
return user.getName().toUpperCase();
```

**Flags:**
- Chained method calls without null checks
- Missing `@Nullable` / `@NonNull` annotations on public APIs
- `Optional.get()` without `isPresent()` check
- Returning `null` from methods that could return `Optional` or empty collection

**Suggest:**
- Use `Optional` for return types that may be absent
- Use `Objects.requireNonNull()` for constructor/method params
- Return empty collections instead of null: `Collections.emptyList()`

### 2. Exception Handling

**Check for:**
```java
// ❌ Swallowing exceptions
try {
    process();
} catch (Exception e) {
    // silently ignored
}

// ❌ Catching too broad
catch (Exception e) { }
catch (Throwable t) { }

// ❌ Losing stack trace
catch (IOException e) {
    throw new RuntimeException(e.getMessage());
}

// ✅ Proper handling
catch (IOException e) {
    log.error("Failed to process file: {}", filename, e);
    throw new ProcessingException("File processing failed", e);
}
```

**Flags:**
- Empty catch blocks
- Catching `Exception` or `Throwable` broadly
- Losing original exception (not chaining)
- Using exceptions for flow control
- Checked exceptions leaking through API boundaries

**Suggest:**
- Log with context AND stack trace
- Use specific exception types
- Chain exceptions with `cause`
- Consider custom exceptions for domain errors

### 3. Collections & Streams

**Check for:**
```java
// ❌ Modifying while iterating
for (Item item : items) {
    if (item.isExpired()) {
        items.remove(item);  // ConcurrentModificationException
    }
}

// ✅ Use removeIf
items.removeIf(Item::isExpired);

// ❌ Stream for simple operations
list.stream().forEach(System.out::println);

// ✅ Simple loop is cleaner
for (Item item : list) {
    System.out.println(item);
}

// ❌ Stream.toList() is unmodifiable (Java 16+)
List<String> names = users.stream()
    .map(User::getName)
    .toList();
names.add("extra");  // UnsupportedOperationException at runtime

// ✅ Collectors.toList() when a mutable list is needed
List<String> names = users.stream()
    .map(User::getName)
    .collect(Collectors.toList());
```

**Flags:**
- Modifying collections during iteration
- Overusing streams for simple operations
- Calling `.add()` / `.remove()` on a list returned by `Stream.toList()` (Java 16+) — it is unmodifiable; use `Collectors.toList()` when mutability is needed
- Not using `List.of()`, `Set.of()`, `Map.of()` for immutable collections
- Parallel streams without understanding implications

**Suggest:**
- `List.copyOf()` for defensive copies
- `removeIf()` instead of iterator removal
- Streams for transformations, loops for side effects

### 4. Concurrency

**Check for:**
```java
// ❌ Not thread-safe
private Map<String, User> cache = new HashMap<>();

// ✅ Thread-safe
private Map<String, User> cache = new ConcurrentHashMap<>();

// ❌ Check-then-act race condition
if (!map.containsKey(key)) {
    map.put(key, computeValue());
}

// ✅ Atomic operation
map.computeIfAbsent(key, k -> computeValue());

// ❌ Double-checked locking (broken without volatile)
if (instance == null) {
    synchronized(this) {
        if (instance == null) {
            instance = new Instance();
        }
    }
}
```

**Flags:**
- Shared mutable state without synchronization
- Check-then-act patterns without atomicity
- Missing `volatile` on shared variables
- Synchronized on non-final objects
- Thread-unsafe lazy initialization

**Suggest:**
- Prefer immutable objects
- Use `java.util.concurrent` classes
- `AtomicReference`, `AtomicInteger` for simple cases
- Consider `@ThreadSafe` / `@NotThreadSafe` annotations

### 4.5 Class Design

**Flags:**
- **God classes** — any class exceeding 200 lines or 10 public methods is a refactoring prompt. Single Responsibility violation: split into focused classes.
- **Application service method size** — methods growing beyond ~50 lines should be evaluated for orchestration complexity. Check whether domain logic has leaked into the service, the use case needs decomposition, or a collaborator is missing. Extraction must improve readability, not fragment logic artificially.
- **Deep inheritance chains** — prefer composition. Inheritance hierarchies beyond 2 levels rarely pay off and make changes ripple unpredictably.
- **Interfaces for testability only** — interfaces are for the strategy pattern (multiple implementations). Single-implementation interfaces add no value: Mockito mocks concrete classes, so "testability" is not a valid reason for an interface.

---

### 5. Java Idioms

**equals/hashCode:**
```java
// ❌ Only equals without hashCode
@Override
public boolean equals(Object o) { ... }
// Missing hashCode!

// ❌ Mutable fields in hashCode
@Override
public int hashCode() {
    return Objects.hash(id, mutableField);  // Breaks HashMap
}

// ✅ Use immutable fields, implement both
@Override
public boolean equals(Object o) {
    if (this == o) return true;
    if (!(o instanceof User user)) return false;
    return Objects.equals(id, user.id);
}

@Override
public int hashCode() {
    return Objects.hash(id);
}
```

**toString:**
```java
// ❌ Missing - hard to debug
// No toString()

// ❌ Including sensitive data
return "User{password='" + password + "'}";

// ✅ Useful for debugging
@Override
public String toString() {
    return "User{id=" + id + ", name='" + name + "'}";
}
```

**Builders:**
```java
// ✅ DTOs are records — canonical constructor, no @Builder needed
public record CreateUserRequest(String name, String email) {}
CreateUserRequest request = new CreateUserRequest("John", "john@example.com");

// ❌ @Builder on domain entities — allows partial construction, bypasses invariants
Order order = Order.builder().customerId(id).build(); // items never set — invalid state

// ✅ Static factory method on domain entities — validates all preconditions before construction
Order order = Order.create(customerId, items);
```

**Note:** `@Builder` on a DTO-like class is only acceptable when `record` genuinely cannot be used (e.g. a framework requires a no-arg constructor and no workaround exists). Mutability must be explicitly justified — not the default.

**Flags:**
- `equals` without `hashCode`
- Mutable fields in `hashCode`
- Missing `toString` on domain objects
- Lazy-loaded JPA associations included in `toString()` — triggers unintended queries and risks `LazyInitializationException` outside a transaction; exclude lazy associations
- Constructors with 5 or more parameters — extract a collaborator class to group related responsibilities; a builder alone does not fix the coupling problem
- Not using `instanceof` pattern matching (Java 16+)

### 6. Resource Management

**Check for:**
```java
// ❌ Resource leak
FileInputStream fis = new FileInputStream(file);
// ... might throw before close

// ✅ Try-with-resources
try (FileInputStream fis = new FileInputStream(file)) {
    // ...
}

// ❌ Multiple resources, wrong order
try (BufferedWriter writer = new BufferedWriter(new FileWriter(file))) {
    // FileWriter might not be closed if BufferedWriter fails
}

// ✅ Separate declarations
try (FileWriter fw = new FileWriter(file);
     BufferedWriter writer = new BufferedWriter(fw)) {
    // Both properly closed
}
```

**Flags:**
- Not using try-with-resources for `Closeable`/`AutoCloseable`
- Resources opened but not in try-with-resources
- Database connections/statements not properly closed

### 7. API Design

**Check for:**
```java
// ❌ Field injection — forbidden
@Autowired
private UserService userService;

// ❌ Setter injection — forbidden
@Autowired
public void setUserService(UserService userService) {
    this.userService = userService;
}

// ✅ Constructor injection — mandatory; use @RequiredArgsConstructor to avoid boilerplate
@RequiredArgsConstructor
public class OrderController {
    private final OrderService orderService;
}

// ❌ Boolean parameters
process(data, true, false);  // What do these mean?

// ✅ Use enums or builder
process(data, ProcessMode.ASYNC, ErrorHandling.STRICT);

// ❌ Returning null for "not found"
public User findById(Long id) {
    return users.get(id);  // null if not found
}

// ✅ Return Optional
public Optional<User> findById(Long id) {
    return Optional.ofNullable(users.get(id));
}

// ❌ Accepting null collections
public void process(List<Item> items) {
    if (items == null) items = Collections.emptyList();
}

// ✅ Require non-null, accept empty
public void process(List<Item> items) {
    Objects.requireNonNull(items, "items must not be null");
}
```

**Flags:**
- `@Autowired` on fields or setters — constructor injection is mandatory
- `@Data` on domain entities or aggregates — it generates public setters that bypass invariant enforcement; only permitted on DTOs and Read Models when a `record` cannot be used
- `@RequiredArgsConstructor` or `@Builder` on domain entities or aggregates — both bypass invariant validation; domain entities must use a private/package-private constructor and a static factory method that validates all preconditions
- `@Transactional` at class level — declare per method only; class-level `readOnly = true` is especially dangerous because a write method added later without an override silently operates without a proper transaction
- `@Transactional` method called from within the same class — Spring's proxy is bypassed and the transaction never starts; extract to a separate Spring bean
- `LocalDateTime` on persisted timestamp fields — use `Instant` or `OffsetDateTime`; `LocalDateTime` has no timezone information and silently produces incorrect data across environments
- `@Enumerated` without `EnumType.STRING` on JPA enum fields — JPA defaults to ordinal, which silently corrupts data when enum values are reordered or new values are inserted before existing ones
- Service methods returning domain entities — services must map to DTOs via mapper before returning; never expose entities at service or API boundaries
- External I/O (HTTP calls, messaging, file operations) inside a `@Transactional` method — a blocked external call holds a DB connection captive, causing connection pool exhaustion under load
- Boolean parameters (prefer enums)
- Methods with > 3 parameters (consider parameter object)
- Inconsistent null handling across similar methods
- Missing validation on public API inputs
- Custom error response records (`ErrorResponse`, `{ code, message }`, etc.) — error responses must use RFC 9457 `ProblemDetail` (`application/problem+json`)
- `@ExceptionHandler` methods returning `ResponseEntity<CustomRecord>` instead of `ProblemDetail`

### 8. Domain Model

**Flags:**
- Anemic model — business logic implemented in a service method that belongs inside an entity (e.g. a service deciding "what makes an order cancellable" instead of `order.canBeCancelled()`)
- Public setters on aggregate roots or child entities — state transitions must go through intention-revealing methods that enforce invariants
- Direct modification of child entities from outside the aggregate — callers must interact with the aggregate root, which delegates to its children
- Mutable collection exposure — `getItems()` returning a live internal list allows callers to bypass invariant enforcement; return `Collections.unmodifiableList()` or `List.copyOf()`
- Domain event constructed or published by a service — events must be raised by the aggregate root that owns the state change; services persist the aggregate, then publish accumulated events after commit
- Cross-aggregate object reference — aggregates must reference other aggregates by ID only, never by object reference
- Business rule in a repository method — repositories are persistence abstractions only; conditional logic or workflow behaviour inside a repository method is a design violation

### 9. Performance Considerations

**Check for:**
```java
// ❌ String concatenation in loop
String result = "";
for (String s : strings) {
    result += s;  // Creates new String each iteration
}

// ✅ StringBuilder
StringBuilder sb = new StringBuilder();
for (String s : strings) {
    sb.append(s);
}

// ❌ Regex compilation in loop
for (String line : lines) {
    if (line.matches("pattern.*")) { }  // Compiles regex each time
}

// ✅ Pre-compiled pattern
private static final Pattern PATTERN = Pattern.compile("pattern.*");
for (String line : lines) {
    if (PATTERN.matcher(line).matches()) { }
}

// ❌ N+1 in loops
for (User user : users) {
    List<Order> orders = orderRepo.findByUserId(user.getId());
}

// ✅ Batch fetch
Map<Long, List<Order>> ordersByUser = orderRepo.findByUserIds(userIds);
```

**Flags:**
- String concatenation in loops
- Regex compilation in loops
- N+1 query patterns
- Creating objects in tight loops that could be reused
- Not using primitive streams (`IntStream`, `LongStream`)

### 10. Testing

See `.claude/skills/test-quality/SKILL.md` for test naming conventions, AAA structure, coverage standards, and assertion patterns. Flag missing tests as part of this review — every new or modified method with business logic requires corresponding test coverage.

---

## Severity Guidelines

| Severity | Criteria |
|----------|----------|
| **Critical** | Security vulnerability, data loss risk, production crash |
| **High** | Bug likely, significant performance issue, breaks API contract |
| **Medium** | Code smell, maintainability issue, missing best practice |
| **Low** | Style, minor optimization, suggestion |

## Token Optimization

- Focus on changed lines (use `git diff`)
- Don't repeat obvious issues - group similar findings
- Reference line numbers, not full code quotes
- Skip files that are auto-generated or test fixtures

## Quick Reference Card

| Category | Key Checks |
|----------|------------|
| Null Safety | Chained calls, Optional misuse, null returns |
| Exceptions | Empty catch, broad catch, lost stack trace |
| Collections | Modification during iteration, `Stream.toList()` mutability, stream vs loop |
| Concurrency | Shared mutable state, check-then-act |
| Idioms | equals/hashCode pair, toString (no lazy associations), builders |
| Resources | try-with-resources, connection leaks |
| API | Boolean params, null handling, validation, `@Transactional` class level + proxy bypass, `LocalDateTime` on timestamps, `@Enumerated` without `EnumType.STRING`, entity returned from service, external I/O in transaction |
| Domain Model | Anemic model, public setters, mutable collection exposure, cross-aggregate object reference, business logic in repository |
| Performance | String concat, regex in loop, N+1 |
| Testing | See `test-quality` skill |

---

## Related Skills

- `jpa-patterns` — JPA/Hibernate patterns: N+1, lazy loading, fetch strategies, transaction boundaries
- `security-audit` — OWASP Top 10, input validation, injection prevention, secrets handling
- `test-quality` — JUnit 5 + AssertJ: test naming, AAA structure, coverage standards, parameterised tests
