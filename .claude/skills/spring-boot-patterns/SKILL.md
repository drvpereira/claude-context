---
name: spring-boot-patterns
description: Spring Boot best practices and patterns. Use when creating controllers, services, repositories, or when user asks about Spring Boot architecture, REST APIs, exception handling, or JPA patterns.
---

# Spring Boot Patterns Skill

Best practices and patterns for Spring Boot applications.

## When to Use
- User says "create controller" / "add service" / "Spring Boot help"
- Reviewing Spring Boot code
- Setting up new Spring Boot project structure

## Project Structure

Feature-based, domain-centric layout. Each feature is a self-contained vertical slice.

```
src/main/java/com/example/myapp/
├── MyAppApplication.java
├── config/                            # Cross-cutting configuration
│   ├── SecurityConfig.java
│   └── WebConfig.java
├── shared/
│   └── exception/
│       ├── GlobalExceptionHandler.java
│       └── ResourceNotFoundException.java  # Shared — thrown by any feature
└── user/                              # One directory per feature
    ├── api/
    │   ├── UserController.java
    │   └── dto/
    │       ├── CreateUserRequest.java
    │       └── UserResponse.java
    ├── domain/
    │   ├── User.java                  # Entity / aggregate root
    │   └── UserRepository.java        # Interface — owned by domain
    ├── exception/
    │   └── UserAlreadyExistsException.java  # Feature-specific business rule violations
    ├── persistence/
    │   ├── JpaUserRepository.java     # Spring Data implementation
    │   └── mapper/
    │       └── UserMapper.java
    └── UserService.java               # Application service
```

See `.claude/conventions/architecture-standards.md` for the preferred package layout and `.claude/skills/clean-architecture/SKILL.md` for dependency-direction rules.

---

## Controller Patterns

### REST Controller Template
```java
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor  // Lombok for constructor injection
public class UserController {

    private final UserService userService;

    @GetMapping
    public ResponseEntity<Page<UserResponse>> getAll(Pageable pageable) {
        return ResponseEntity.ok(userService.findAll(pageable));
    }

    @GetMapping("/{id}")
    public ResponseEntity<UserResponse> getById(@PathVariable Long id) {
        return ResponseEntity.ok(userService.findById(id));
    }

    @PostMapping
    public ResponseEntity<UserResponse> create(
            @Valid @RequestBody CreateUserRequest request) {
        UserResponse created = userService.create(request);
        URI location = ServletUriComponentsBuilder.fromCurrentRequest()
            .path("/{id}")
            .buildAndExpand(created.id())
            .toUri();
        return ResponseEntity.created(location).body(created);
    }

    @PutMapping("/{id}")
    public ResponseEntity<UserResponse> update(
            @PathVariable Long id,
            @Valid @RequestBody UpdateUserRequest request) {
        return ResponseEntity.ok(userService.update(id, request));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        userService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
```

### Controller Best Practices

| Practice | Example |
|----------|---------|
| Versioned API | `/api/v1/users` |
| Plural nouns | `/users` not `/user` |
| HTTP methods | GET=read, POST=create, PUT=full replace, PATCH=partial update only (never full replace), DELETE=delete |
| Status codes | 200=OK, 201=Created, 204=NoContent, 400=BadRequest, 422=UnprocessableEntity, 404=NotFound |
| Request body validation | `@Valid` on `@RequestBody` parameter |
| Path / query param validation | `@Validated` on controller class + constraint annotations on `@PathVariable` / `@RequestParam` directly |

### ❌ Anti-patterns
```java
// ❌ Business logic in controller; LocalDateTime forbidden on persisted timestamps (no timezone — use Instant)
@PostMapping
public User create(@RequestBody User user) {
    user.setCreatedAt(LocalDateTime.now());  // Logic belongs in service; type must be Instant or OffsetDateTime
    return userRepository.save(user);         // Direct repo access — bypasses service layer
}

// ❌ Returning entity directly (exposes internals); .get() without isPresent() risks NoSuchElementException
@GetMapping("/{id}")
public User getById(@PathVariable Long id) {
    return userRepository.findById(id).get();
}
```

---

## Service Patterns

### Service Template
```java
// Concrete class by default — no interface unless the strategy pattern applies (multiple implementations exist)
@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;

    @Transactional(readOnly = true)
    public Page<UserResponse> findAll(Pageable pageable) {
        return userRepository.findAll(pageable)
            .map(userMapper::toResponse);
    }

    @Transactional(readOnly = true)
    public UserResponse findById(Long id) {
        return userRepository.findById(id)
            .map(userMapper::toResponse)
            .orElseThrow(() -> new ResourceNotFoundException("User", id));
    }

    @Transactional
    public UserResponse create(CreateUserRequest request) {
        User user = User.create(request.name(), request.email(), request.age());
        User saved = userRepository.save(user);
        return userMapper.toResponse(saved);
    }

    @Transactional
    public UserResponse update(Long id, UpdateUserRequest request) {
        User user = userRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("User", id));
        user.update(request.name(), request.email());  // intention-revealing method
        return userMapper.toResponse(user);
    }

    @Transactional
    public void delete(Long id) {
        if (!userRepository.existsById(id)) {
            throw new ResourceNotFoundException("User", id);
        }
        userRepository.deleteById(id);
    }
}
```

### Service Best Practices

- `@Transactional(readOnly = true)` on read methods, `@Transactional` on write methods — never at class level (a write method added later without an explicit override silently operates without a proper transaction)
- Never call a `@Transactional` method from another method in the same class — Spring's proxy is bypassed and the transaction never starts; extract to a separate bean
- Throw domain exceptions, not generic ones
- Use mappers (MapStruct) for entity → DTO conversion only — entity creation and mutation go through factory methods and intention-revealing entity methods, never through a mapper
- **Constructor injection only** — `@Autowired` on fields and setter injection are forbidden in production code. Use `@RequiredArgsConstructor` (Lombok) to avoid boilerplate.
- **Test infrastructure exception**: Spring-managed test beans (`MockMvc`, `TestEntityManager`, `WebTestClient`, beans declared via `@MockitoBean` / `@SpyBean`) cannot be constructor-injected — `@Autowired` field injection is acceptable on test classes only. The constructor-injection rule applies to production beans (`@Service`, `@Component`, `@RestController`, etc.).
- **Keep constructors small** — if a constructor requires 5 or more arguments, the class has too many direct dependencies. Extract a collaborator class to group related responsibilities and reduce coupling.

---

## Repository Patterns

### JPA Repository
```java
public interface UserRepository extends JpaRepository<User, Long> {

    // Derived query
    Optional<User> findByEmail(String email);

    Page<User> findByActiveTrue(Pageable pageable);

    // Custom query
    @Query("SELECT u FROM User u WHERE u.department.id = :deptId")
    Page<User> findByDepartmentId(@Param("deptId") Long departmentId, Pageable pageable);

    // Native query (use sparingly) — countQuery is mandatory for Page return with native queries;
    // Spring Data cannot auto-derive a count query from native SQL
    @Query(value = "SELECT * FROM users WHERE created_at > :date",
           countQuery = "SELECT count(*) FROM users WHERE created_at > :date",
           nativeQuery = true)
    Page<User> findRecentUsers(@Param("date") Instant date, Pageable pageable);  // Instant — created_at is a timestamp

    // Exists check (more efficient than findBy)
    boolean existsByEmail(String email);

    // Count
    long countByActiveTrue();
}
```

### Repository Best Practices

- Use derived queries when possible
- `Optional` for single results
- `existsBy` instead of `findBy` for existence checks
- Avoid native queries unless necessary
- Use `@EntityGraph` for fetch optimization

---

## DTO Patterns

### Request/Response DTOs
```java
// Request DTO with validation
public record CreateUserRequest(
    @NotBlank(message = "Name is required")
    @Size(min = 2, max = 100)
    String name,

    @NotBlank
    @Email(message = "Invalid email format")
    String email,

    @NotNull
    @Min(18)
    Integer age
) {}

// Response DTO
public record UserResponse(
    Long id,
    String name,
    String email,
    Instant createdAt  // always Instant or OffsetDateTime — never LocalDateTime
) {}
```

### MapStruct Mapper
```java
// toResponse only — entity creation and mutation go through factory methods and entity methods, never mappers.
@Mapper(componentModel = "spring")
public interface UserMapper {

    UserResponse toResponse(User entity);

    List<UserResponse> toResponseList(List<User> entities);
}
```

---

## Exception Handling

All error responses follow **RFC 9457 Problem Details** (`application/problem+json`).  
Enable built-in Spring exception handling: `spring.mvc.problemdetails.enabled=true`

### Custom Exceptions
```java
public class ResourceNotFoundException extends RuntimeException {

    public ResourceNotFoundException(String resource, Long id) {
        super(String.format("%s not found with id: %d", resource, id));
    }
}

public class BusinessException extends RuntimeException {

    private final String code;  // used for logging and optional type URI suffix

    public BusinessException(String code, String message) {
        super(message);
        this.code = code;
    }

    public String getCode() {
        return code;
    }
}
```

### Global Exception Handler
```java
// Extension member for validation errors — set as a ProblemDetail property.
// Named ValidationError to avoid collision with org.springframework.validation.FieldError.
public record ValidationError(String field, String message) {}

@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    public ProblemDetail handleNotFound(ResourceNotFoundException ex, HttpServletRequest request) {
        log.warn("Resource not found: {}", ex.getMessage());
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
        problem.setTitle("Resource Not Found");
        problem.setInstance(URI.create(request.getRequestURI()));
        return problem;
    }

    @ExceptionHandler(BusinessException.class)
    public ProblemDetail handleBusiness(BusinessException ex, HttpServletRequest request) {
        log.warn("Business rule violation [{}]: {}", ex.getCode(), ex.getMessage());
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.UNPROCESSABLE_ENTITY, ex.getMessage());
        problem.setTitle("Business Rule Violation");
        problem.setInstance(URI.create(request.getRequestURI()));
        return problem;
    }

    // Handles @RequestBody validation failures (@Valid on request body)
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex, HttpServletRequest request) {
        List<ValidationError> errors = ex.getBindingResult().getFieldErrors().stream()
            .map(e -> new ValidationError(e.getField(), e.getDefaultMessage()))
            .toList();
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.UNPROCESSABLE_ENTITY, "One or more fields are invalid");
        problem.setTitle("Validation Failed");
        problem.setInstance(URI.create(request.getRequestURI()));
        problem.setProperty("errors", errors);  // RFC 9457 extension member
        return problem;
    }

    // Handles @PathVariable and @RequestParam validation failures (@Validated on controller class)
    @ExceptionHandler(ConstraintViolationException.class)
    public ProblemDetail handleConstraintViolation(ConstraintViolationException ex, HttpServletRequest request) {
        List<ValidationError> errors = ex.getConstraintViolations().stream()
            .map(v -> {
                String field = v.getPropertyPath().toString();
                // Strip method name prefix — e.g. "getById.id" → "id"
                field = field.contains(".") ? field.substring(field.lastIndexOf('.') + 1) : field;
                return new ValidationError(field, v.getMessage());
            })
            .toList();
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.UNPROCESSABLE_ENTITY, "One or more parameters are invalid");
        problem.setTitle("Validation Failed");
        problem.setInstance(URI.create(request.getRequestURI()));
        problem.setProperty("errors", errors);
        return problem;
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail handleGeneric(Exception ex, HttpServletRequest request) {
        log.error("Unexpected error", ex);
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred");
        problem.setTitle("Internal Server Error");
        problem.setInstance(URI.create(request.getRequestURI()));
        return problem;
    }
}
```

### Response shapes (`application/problem+json`)

**Not found (404):**
```json
{
  "type": "about:blank",
  "title": "Resource Not Found",
  "status": 404,
  "detail": "User not found with id: 42",
  "instance": "/api/v1/users/42"
}
```

**Validation error (422):**
```json
{
  "type": "about:blank",
  "title": "Validation Failed",
  "status": 422,
  "detail": "One or more fields are invalid",
  "instance": "/api/v1/users",
  "errors": [
    { "field": "email", "message": "Invalid email format" }
  ]
}
```

**Business rule violation (422):**
```json
{
  "type": "about:blank",
  "title": "Business Rule Violation",
  "status": 422,
  "detail": "Payment declined: insufficient funds",
  "instance": "/api/v1/payments"
}
```

> `type` defaults to `about:blank`. Set a meaningful URI per problem type to link to documentation:
> `problem.setType(URI.create("https://api.example.com/problems/not-found"))`

---

## Configuration Patterns

### Application Properties
```yaml
# application.yml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/mydb
    username: ${DB_USER}
    password: ${DB_PASSWORD}
  jpa:
    hibernate:
      ddl-auto: validate  # Never 'create', 'update', or 'create-drop' in production — use versioned migrations (Flyway/Liquibase)
    show-sql: false

app:
  jwt:
    secret: ${JWT_SECRET}
    expiration: 86400000
```

### Max Page Size Enforcement

Every list endpoint must enforce a maximum page size. Requests exceeding the limit must be rejected with `400 Bad Request`.

```java
// WebConfig.java — configure once, applies to all Pageable parameters
@Bean
public PageableHandlerMethodArgumentResolverCustomizer pageableResolverCustomizer() {
    return resolver -> {
        resolver.setMaxPageSize(100);                          // rejects with 400 if exceeded
        resolver.setFallbackPageable(PageRequest.of(0, 50));  // default page size: 50
    };
}
```

### Configuration Properties Class
```java
// Spring Boot 3+: use a record — immutable, constructor-bound, no getters/setters needed
@ConfigurationProperties(prefix = "app.jwt")
@Validated
public record JwtProperties(

    @NotBlank
    String secret,

    @Min(60000)
    long expiration
) {}
```

### Profile-Specific Configuration
```
src/main/resources/
├── application.yml           # Common config
├── application-dev.yml       # Development
├── application-test.yml      # Testing
└── application-prod.yml      # Production
```

---

## Common Annotations Quick Reference

| Annotation | Purpose |
|------------|---------|
| `@RestController` | REST controller (combines @Controller + @ResponseBody) |
| `@Service` | Application service / orchestration component |
| `@Repository` | Data access component |
| `@Configuration` | Configuration class |
| `@RequiredArgsConstructor` | Lombok: constructor injection |
| `@Transactional` | Transaction management |
| `@Valid` | Trigger validation |
| `@ConfigurationProperties` | Bind properties to class |
| `@Profile("dev")` | Profile-specific bean |
| `@Scheduled` | Scheduled tasks |

---

## Testing Patterns

### Controller Test (MockMvc)
```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean  // Spring Boot 3.4+: @MockBean is deprecated; use @MockitoBean
    private UserService userService;

    @Test
    @DisplayName("should return user when found by id")
    void shouldReturnUser() throws Exception {
        when(userService.findById(1L))
            .thenReturn(new UserResponse(1L, "John", "john@example.com", null));

        mockMvc.perform(get("/api/v1/users/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("John"));
    }
}
```

### Service Test
```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private UserMapper userMapper;

    @InjectMocks
    private UserService userService;

    @Test
    @DisplayName("should throw when user is not found")
    void shouldThrowWhenUserNotFound() {
        when(userRepository.findById(1L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> userService.findById(1L))
            .isInstanceOf(ResourceNotFoundException.class);
    }
}
```

### Integration Test
```java
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class UserIntegrationTest {

    @Container
    @ServiceConnection
    static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8");

    @Autowired
    private MockMvc mockMvc;

    @Test
    @DisplayName("should create user and return 201 Created with Location header")
    void shouldCreateUser() throws Exception {
        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"name": "John", "email": "john@example.com", "age": 25}
                    """))
            .andExpect(status().isCreated())
            .andExpect(header().exists("Location"));
    }
}
```

---

## Quick Reference Card

| Layer | Responsibility | Annotations |
|-------|---------------|-------------|
| Controller | HTTP handling, validation | `@RestController`, `@Valid` |
| Service | Orchestration, transactions | `@Service`, `@Transactional` |
| Repository | Data access | `@Repository`, extends `JpaRepository` |
| DTO | Data transfer | Records with validation annotations |
| Config | Configuration | `@Configuration`, `@ConfigurationProperties` |
| Exception | Error handling | `@RestControllerAdvice` |

---

## Related Skills

**Architecture paradigms:**
- `clean-architecture` — layered architecture, dependency direction, transaction-boundary placement, framework isolation
- `domain-driven-design` — Rich Domain Model, aggregates, domain events, repositories per aggregate root

**JPA / persistence:**
- `jpa-patterns` — index of JPA skills + permitted annotations on domain objects
- `jpa-fetching` — N+1 prevention, lazy loading, `LazyInitializationException` resolution
- `jpa-transactions` — `@Transactional` placement, propagation, proxy-bypass mistakes
- `jpa-relationships` — entity associations, cascade behaviour, `equals`/`hashCode`
- `jpa-queries` — pagination, DTO projections, bulk DML
- `jpa-locking` — `@Version` optimistic locking, `OptimisticLockException` handling

**REST surface & quality:**
- `http-semantics` — HTTP method contracts, status codes, RFC 9457 ProblemDetail error format
- `idempotency` — idempotency key patterns for mutating endpoints
- `security-audit` — OWASP Top 10, input validation, injection prevention, secrets handling
- `test-quality` — JUnit 5 + AssertJ: test naming, AAA structure, coverage standards, parameterised tests
- `java-code-review` — null safety, exception handling, concurrency, class design, performance
