---
name: spring-security
description: Spring Security 6 patterns — SecurityFilterChain configuration, authentication (JWT, OAuth2, basic), authorisation (@PreAuthorize, method security), password storage, CORS, CSRF, and session management. Use when configuring Spring Security or reviewing auth/authz code.
---

# Spring Security

Spring Security 6 configuration patterns for Spring Boot 3.x. This skill covers the framework; for the threat model and what to defend against, see `.claude/skills/security-audit/SKILL.md`.

## When to Use
- Configuring `SecurityFilterChain` for a new service
- Adding `@PreAuthorize` / `@PostAuthorize` to a controller or service
- Reviewing authentication or authorisation code
- Designing JWT / OAuth2 integration
- Debugging "403 Forbidden" or "401 Unauthorized" responses

---

## SecurityFilterChain — Boilerplate

Spring Security 6 uses the lambda-DSL `SecurityFilterChain` bean. The old `WebSecurityConfigurerAdapter` is removed.

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity  // enables @PreAuthorize / @PostAuthorize
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(AbstractHttpConfigurer::disable)  // stateless REST API
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/health/**", "/api/v1/auth/login").permitAll()
                .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
            .build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
```

**Rules:**
- Disable CSRF only for stateless REST APIs that authenticate via tokens. Keep CSRF protection enabled for any endpoint that reads a session cookie.
- Use `SessionCreationPolicy.STATELESS` for token-based APIs — no server-side session, no JSESSIONID cookie.
- `.anyRequest().authenticated()` must be the final rule — never `.permitAll()` as a catch-all.

---

## Authorisation

### Method-Level Security (Preferred)

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    @PreAuthorize("hasRole('ADMIN') or @orderSecurity.isOwner(#orderId, authentication.principal)")
    @Transactional(readOnly = true)
    public OrderDTO findById(Long orderId, Authentication authentication) {
        // ...
    }

    @PreAuthorize("hasAuthority('order:write')")
    @Transactional
    public OrderDTO cancel(Long orderId) {
        // ...
    }
}
```

- **`@PreAuthorize` runs before the method** — preferred for write operations and any guard
- **`@PostAuthorize` runs after** — use rarely (returning a forbidden resource is an information leak; prefer `@PreAuthorize`)
- Custom SpEL beans (`@orderSecurity.isOwner(...)`) for complex domain-aware checks

### Defence in Depth

- **Authorisation belongs in the service layer**, not only the controller. A controller `@PreAuthorize` is UI convenience; service-layer enforcement is the security boundary.
- Internal callers (event handlers, scheduled jobs) bypass controller annotations — only service-layer guards protect them.

---

## Authentication

### JWT — OAuth2 Resource Server

```java
@Bean
public JwtDecoder jwtDecoder(@Value("${auth.jwk-set-uri}") String jwkSetUri) {
    return NimbusJwtDecoder.withJwkSetUri(jwkSetUri).build();
}

@Bean
public JwtAuthenticationConverter jwtAuthenticationConverter() {
    JwtGrantedAuthoritiesConverter granted = new JwtGrantedAuthoritiesConverter();
    granted.setAuthorityPrefix("ROLE_");
    granted.setAuthoritiesClaimName("roles");

    JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
    converter.setJwtGrantedAuthoritiesConverter(granted);
    return converter;
}
```

**Rules:**
- Validate the JWT signature against the JWKS endpoint — never trust an unsigned or HS256-signed token from an external IdP
- Validate `iss` (issuer), `aud` (audience), and `exp` (expiry) claims — Spring's `OAuth2ResourceServerConfigurer` does this when configured with `jwkSetUri`
- Never log raw JWT tokens — include only the `sub` claim and request ID in logs

### Basic Auth — Internal Only

Basic auth is acceptable for internal service-to-service calls behind a private network. Never expose basic auth on public endpoints.

---

## Password Storage

```java
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);  // strength 12 — adjust based on hardware
}

@Service
@RequiredArgsConstructor
public class UserService {

    private final PasswordEncoder passwordEncoder;

    public void register(RegisterRequest request) {
        String hash = passwordEncoder.encode(request.password());
        // store hash, never the raw password
    }
}
```

**Rules:**
- Use `BCryptPasswordEncoder` with strength ≥ 10 (default), 12 recommended for modern hardware
- Argon2 (`Argon2PasswordEncoder`) is preferred for new systems where supported
- Never store plaintext passwords — even temporarily, even in test fixtures
- Never log password fields — sanitise request DTOs before any logging

---

## CORS

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    config.setAllowedOrigins(List.of("https://app.example.com"));  // explicit list, never "*"
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE"));
    config.setAllowedHeaders(List.of("Authorization", "Content-Type", "Idempotency-Key"));
    config.setAllowCredentials(true);
    config.setMaxAge(3600L);

    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/api/**", config);
    return source;
}
```

**Rules:**
- Never use `*` for allowed origins on credentialed endpoints (the spec forbids it; browsers reject it)
- Use an explicit allowlist of origins — environment-driven from configuration, not hardcoded
- Set `maxAge` to reduce preflight overhead but keep it short enough that origin changes propagate

---

## CSRF Protection

- **REST APIs with bearer tokens**: disable CSRF (`csrf().disable()`). Bearer tokens are not subject to CSRF because they are not automatically attached by the browser.
- **Cookie-based session APIs**: keep CSRF enabled. Use the `CookieCsrfTokenRepository.withHttpOnlyFalse()` pattern for SPA clients that need to read the token from a cookie.
- **Never disable CSRF "to make local testing easier"** — disable only when the threat model genuinely does not require it.

---

## Session Management

```java
http.sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS));
```

- Stateless REST APIs: `STATELESS` policy, no `JSESSIONID` cookie
- Stateful applications: enable session fixation protection (`sessionFixation().migrateSession()` is the default in Spring Security 6)
- Session timeout: configure in `application.yml` (`server.servlet.session.timeout`) and document in the spec

---

## Security Headers

Spring Security 6 enables sensible defaults. Verify these are not disabled:
- `Strict-Transport-Security` — enabled on HTTPS
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Content-Security-Policy` — define in your config; Spring does not set a default

```java
http.headers(headers -> headers
    .contentSecurityPolicy(csp -> csp.policyDirectives(
        "default-src 'self'; script-src 'self'; object-src 'none'"))
    .frameOptions(FrameOptionsConfig::deny)
);
```

---

## Testing Security

```java
@WebMvcTest(OrderController.class)
class OrderControllerSecurityTest {

    @Autowired private MockMvc mockMvc;
    @MockitoBean private OrderService orderService;

    @Test
    @WithMockUser(roles = "ADMIN")
    @DisplayName("admin can access admin endpoints")
    void adminCanAccess() throws Exception {
        mockMvc.perform(get("/api/v1/admin/orders"))
            .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "USER")
    @DisplayName("regular user is forbidden from admin endpoints")
    void userIsForbidden() throws Exception {
        mockMvc.perform(get("/api/v1/admin/orders"))
            .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("unauthenticated request is rejected with 401")
    void anonymousIsUnauthorized() throws Exception {
        mockMvc.perform(get("/api/v1/orders"))
            .andExpect(status().isUnauthorized());
    }
}
```

- Every protected endpoint must have at least three tests: authorised, forbidden, anonymous
- `@WithMockUser` sets the principal for the test method scope
- For JWT-specific behaviour, use `SecurityMockMvcRequestPostProcessors.jwt()` to set claims

---

## Anti-Patterns

- **Authorisation only at the controller** — service-layer enforcement is the real boundary
- **`hasRole("...")` and `hasAuthority("ROLE_...")` mixed inconsistently** — pick one convention; Spring's `hasRole` adds the `ROLE_` prefix automatically
- **`permitAll()` as a catch-all** — explicit allowlist only; default deny
- **CSRF disabled "because of CORS issues"** — these are unrelated; CSRF protection is orthogonal to CORS
- **Storing JWTs in `localStorage` on the SPA side** — vulnerable to XSS; use `httpOnly` cookies or in-memory storage

---

## Related Skills

- `security-audit` — OWASP Top 10 threat model, input validation, injection prevention
- `spring-boot-patterns` — controller / service patterns that Spring Security wraps
- `idempotency` — idempotency keys interact with authenticated user context
- `http-semantics` — 401 vs 403 distinction, RFC 9457 ProblemDetail for auth failures
