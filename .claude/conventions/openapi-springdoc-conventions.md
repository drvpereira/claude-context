# OpenAPI / SpringDoc Conventions

**Status:** Authoritative platform standard. The generated `openapi.yaml` is the API contract; Bump.sh is the publication target. **Annotations on Java code are the single source of truth — hand-edited YAML is a Blocker.**

Every rule ends with **[Planning] / [Implementation] / [PR Review] / [CI Gate]** marking its enforcement point. Reviewer-runnable PR checklist lives in [`openapi-review-checklist.md`](openapi-review-checklist.md).

> **Placeholders:** values in `{braces}` such as `{team-email}` or `{base-package}` are defined once in `CLAUDE.md` → *Project Settings*. Always use the configured value; if a value is still *not set*, ask the user before writing it into code or docs.

## Purpose & Scope

How every REST API in the platform documents itself through SpringDoc annotations.

**Out of scope:**
- Async messaging contracts → [`asyncapi-springwolf-conventions.md`](asyncapi-springwolf-conventions.md)
- Spring Security wiring (`SecurityFilterChain`, JWT validation) → [`.claude/skills/spring-security/SKILL.md`](../skills/spring-security/SKILL.md)
- Endpoint design (HTTP method choice, status semantics) → [`.claude/skills/http-semantics/SKILL.md`](../skills/http-semantics/SKILL.md)

## Cross-references

- [`engineering-principles.md`](engineering-principles.md) — API versioning, breaking-change definition, idempotency, pagination
- [`architecture-standards.md`](architecture-standards.md) — paginated response shape, ProblemDetail mandate
- [`definition-of-done.md`](definition-of-done.md) — pre-merge checklist
- [`asyncapi-springwolf-conventions.md`](asyncapi-springwolf-conventions.md) — sibling convention
- [`.claude/skills/idempotency/SKILL.md`](../skills/idempotency/SKILL.md)

## Tooling

Shared schema definitions referenced by the published spec should live in the shared library `{commons-library}`, not be redefined per service:

| Concern | Location |
|---|---|
| Reusable schemas (`ProblemDetail`, `Page`, `Pageable`, `Sort`) | A shared OpenAPI schema configuration class in `{commons-library}` (e.g. `OpenApiSchemaConfig`) |

| Rule | Tag |
|---|---|
| Every service exposing endpoints MUST produce a complete `openapi.yaml`. | **[CI Gate]** |
| The published `openapi.yaml` MUST be machine-generated from annotations — hand-edits are a Blocker. | **[CI Gate]** |
| The published spec MUST contain only this service's own endpoints — foreign endpoints from shared libraries (`{commons-library}`, SpringWolf internals, etc.) MUST NOT leak in. Achieved by setting `springdoc.packages-to-scan={base-package}.<service-name>` in `application.properties`. | **[CI Gate]** |
| `springdoc.packages-to-scan` MUST also be set, with the same value, in `src/test/resources/application.properties`. Spring Boot's test classpath replaces — does not merge with — the main `application.properties`, so the doc-generation test (which writes the published spec) reads only the test copy. | **[CI Gate]** |
| The published spec MUST NOT redefine `ProblemDetail`, `Page`, `Pageable`, or `Sort` — each appears exactly once, sourced from `{commons-library}`. | **[CI Gate]** |

## Core Models

### Error Model

Every error response in the published spec MUST reference a concrete error schema and a non-`*/*` media type. **Empty `@Content` on an error response is a Blocker** — published responses without a schema break consumer client generation. The specific schema (e.g. `ProblemDetail`, an upstream-mirroring envelope) is an implementation choice; the documentation requirement is only that the response is fully documented.

```java
// Documented error response — points at a concrete schema and media type:
content = @Content(mediaType = "application/problem+json",
                   schema = @Schema(ref = "#/components/schemas/ProblemDetail"))
```

When a service uses a centralised `ProblemDetail`, the published spec MUST reference it, not redefine it. **[CI Gate]**

**Every endpoint MUST declare every status it can actually return — and MUST NOT declare a status it cannot.** Which statuses a given endpoint can return is a function of the service's own implementation (its exception-to-status mapping, its global error handler, the upstream services it calls). The convention's job is to ensure those statuses appear in the published spec; the convention does NOT prescribe what the mapping should be. **[PR Review]**

> *Reference for services using a global `@RestControllerAdvice` exception handler* — see [Appendix A](#appendix-a--reference-exception--status-mapping) at the bottom of this document. Non-normative.

### Security Model — Documentation Rules

The convention does **not** prescribe what authentication mechanism a service uses — that is an implementation decision. The convention only governs **how the chosen mechanism is documented** in the published spec.

| Rule | Tag |
|---|---|
| The published `components.securitySchemes` MUST mirror what the service actually accepts. Services with JWT bearer auth declare `bearerAuth`; services with HTTP Basic for an external integration declare an additional `basicAuth`; services with no HTTP authentication (internal-only, network-protected) declare nothing. Drift between the declared schemes and runtime behaviour is a Blocker. | **[PR Review]** |
| `@Parameter(name = "Authorization", …)` on any endpoint is a Blocker — security schemes belong in `components.securitySchemes`, not as parameters. | **[CI Gate]** |
| When the service declares a global `security` default in `OpenApiConfig`, every operation that **does not** require that default MUST opt out explicitly with `@SecurityRequirements({})`. Silent absence is forbidden — the published spec MUST never lie about whether an endpoint is protected. | **[PR Review]** |
| `@Operation.description` MUST state the required role(s) when the endpoint is role-protected — role information from `@Secured` (and equivalents) is invisible to the published spec otherwise. | **[PR Review]** |
| Where a service legitimately uses multiple schemes (e.g. bearer for internal callers, basic for an external partner), each operation MUST reference the scheme it actually accepts via `@SecurityRequirement(name = "…")`. | **[PR Review]** |

> **Note.** The platform's recommended pattern remains *Pattern B*: declare a single `bearerAuth` scheme as the global default in `OpenApiConfig`, and have operations that opt out (or use a different scheme) override explicitly. This is a recommendation for consistency across the platform, not a convention requirement.

**Authorisation description patterns:**

| Pattern | Description text |
|---|---|
| Single role | `"Requires \`ROLE_CUSTOMER\`."` |
| Any of several | `"Requires one of: \`ROLE_CUSTOMER\`, \`ROLE_ADMIN\`."` |
| Resource ownership | `"Requires \`ROLE_CUSTOMER\` AND the principal must own the resource. Cross-user access returns 403."` |

**Sensitive data — forbidden in any published schema:**

| Category | Examples |
|---|---|
| Secrets | passwords, API keys, JWTs, refresh tokens, OTPs |
| Bearer-equivalent internal IDs | session tokens, identity-provider session / order references, signing session IDs |
| Operationally irrelevant PII | name / email / phone on endpoints that don't need them |

For write-only fields: `@Schema(accessMode = Schema.AccessMode.WRITE_ONLY)`. For read-only: `READ_ONLY`. `@JsonIgnore` is runtime behaviour, NOT documentation. **[PR Review]**

**PII fields** MUST be marked in `@Schema.description` (e.g. `"PII — data classification: Confidential."`) and use clearly fictitious examples:

| Field | Acceptable example | Forbidden |
|---|---|---|
| Email | `jane.doe@example.com` | Real domains |
| Phone | `+46700000000` | Real personal numbers |
| Personnummer (SE) | `19000101-0000` | Any pattern that could be real |
| Card PAN | `4111 1111 1111 1111` (test BIN) | Any production-issuable PAN |
| Name | `Jane Doe` | Real names |

### Pagination

The page shape (`{ content, totalElements, totalPages, number }`), the platform-recommended default and maximum page sizes, and the `Page` schema are defined in [`architecture-standards.md`](architecture-standards.md). The defaults and maximums are an **implementation choice per endpoint** — the documentation convention's job is to ensure the published spec reflects whatever each endpoint actually implements, not to dictate the numbers.

Every list endpoint MUST:

| Element | Requirement | Tag |
|---|---|---|
| `page` query param | `@Parameter` with `description`, realistic `example`, and `schema` declaring the actual `defaultValue` and `minimum` the endpoint implements | **[PR Review]** |
| Page-size query param (`size`, `pageSize`, or service-local name) | `@Parameter` with `description`, realistic `example`, and `schema` declaring the actual `defaultValue`, `minimum`, and `maximum` the endpoint implements | **[PR Review]** |
| `sort` query param | `@Parameter` with `description`, repeatable, realistic `example`; description MUST enumerate sortable fields when not all are sortable | **[PR Review]** |
| Endpoint `description` | One sentence stating the endpoint is paginated AND the **actual** default and maximum page size, e.g. *"Returns a paginated response. Default page size is 20; maximum is 100."* The numbers MUST match the `defaultValue` and `maximum` declared on the page-size `@Parameter` schema. | **[PR Review]** |
| `200` response body | `@Content(array = @ArraySchema(schema = @Schema(implementation = T.class)))` — without this, published `content` is `object` | **[CI Gate]** |

## Controller Rules

### `OpenApiConfig` — canonical example

Example for the **most common shape** — JWT-bearer-protected service with a single global security default. Services with a different auth posture (multiple schemes, or no HTTP auth at all) adapt the security blocks to match their implementation, per the [Security Model](#security-model--documentation-rules) section.

```java
@Configuration
@OpenAPIDefinition(
    info = @Info(
        title       = "Orders API",                          // {Service Display Name} + " API"
        description = "...",                                  // see info.description rubric below
        version     = "${app.version}",                       // any non-empty value; semver recommended
        contact     = @Contact(name = "{team-name}", email = "{team-email}"),
        // info.license intentionally omitted — see `info` block table below
    ),
    servers = {
        @Server(url = "{api-url-stg}", description = "stg"),
        @Server(url = "{api-url-prd}", description = "prd")
    },
    tags = { @Tag(name = "Orders", description = "Order placement and lifecycle") },
    security = @SecurityRequirement(name = "bearerAuth")    // omit when the service has no global security default
)
@SecurityScheme(                                            // omit when the service has no HTTP auth
    name = "bearerAuth", type = SecuritySchemeType.HTTP, scheme = "bearer", bearerFormat = "JWT"
)
public class OpenApiConfig { }
```

| Rule | Tag |
|---|---|
| Published `info.version` MUST be present and non-empty. | **[CI Gate]** |
| Each `servers[].description` MUST be one of `stg` or `prd` — lowercase, no decoration. | **[PR Review]** |
| Default `servers[].url` values are `{api-url-stg}` (stg) and `{api-url-prd}` (prd). Services that legitimately serve from a different host (separate gateway, public-only, etc.) MUST override and document the variant in the OpenApiConfig comment. | **[PR Review]** |
| Every controller `@Tag` MUST be registered in `@OpenAPIDefinition.tags`. | **[PR Review]** |
| Tag name MUST match the business-domain name in `docs/business/<domain>/`. | **[PR Review]** |

### Controller class

| Annotation | Required attributes |
|---|---|
| `@Tag` | `name` (Title Case, plural business noun), `description` (one sentence, business capability) |

Generic tags (`"API"`, `"Controller"`, `"V1"`) and class-name tags are forbidden. **[PR Review]**

Security requirements on operations are governed by the [Security Model](#security-model--documentation-rules) section — the convention does not prescribe a specific scheme.

### Endpoint method

| Annotation | Required attributes |
|---|---|
| `@Operation` | `summary` (≤60 chars, imperative, no trailing period); `description` (2–6 sentences: what / when / preconditions / postconditions / side effects); `operationId` (camelCase, stable, globally unique within service) |
| `@ApiResponse` (repeatable) | Every status the endpoint can return |

**Stack multiple `@ApiResponse` annotations directly on the method. Do NOT wrap in `@ApiResponses({ … })`** — the aggregator is redundant on `@Repeatable` annotations and SonarQube flags it. **[CI Gate]**

```java
@ApiResponse(responseCode = "201", description = "Order accepted.",
    content = @Content(schema = @Schema(implementation = OrderResponse.class)))
@ApiResponse(responseCode = "401", description = "Unauthenticated.",
    content = @Content(mediaType = "application/problem+json",
                       schema = @Schema(ref = "#/components/schemas/ProblemDetail")))
```

| Rule | Tag |
|---|---|
| Declare every status the endpoint can produce. | **[PR Review]** |
| Never declare a status the endpoint cannot produce. | **[PR Review]** |
| `description` per response = business condition, not HTTP semantic ("Customer not found" ✓; "Not Found" ✗). | **[PR Review]** |
| Utility endpoints (`/actuator/health`, `/version`) may use a one-sentence `description`. | **[PR Review]** |

### Parameters & request body

| Position | Annotation | Mandatory attributes |
|---|---|---|
| `@PathVariable`, `@RequestParam`, `@RequestHeader` (excluding `Authorization`) | `@Parameter` | `name`, `description`, `required` (explicit), `example` (realistic) |
| Request body | `@io.swagger.v3.oas.annotations.parameters.RequestBody` | `description`, `required`, `content` |

| Rule | Tag |
|---|---|
| `example` MUST be realistic — never `"string"`, `"foo"`, `"123"`. | **[CI Gate]** |
| `hidden = true` permitted ONLY for parameters that are server-injected (not client-supplied). | **[PR Review]** |
| `Authorization` `@Parameter` is FORBIDDEN — authentication MUST be expressed via `components.securitySchemes`, not as a per-endpoint parameter. | **[CI Gate]** |
| Document custom headers (`Idempotency-Key`, correlation IDs) as `@Parameter(in = ParameterIn.HEADER, …)`. | **[Implementation]** |

## Schema Rules

Every DTO / record / value object exposed via the API.

### Class-level

`@Schema(description = …)` — one sentence stating what the object represents in the domain. Reads as a glossary entry. **[PR Review]**

### Field-level

Every record component / field MUST carry:

| Attribute | Required when | Rule |
|---|---|---|
| `description` | Always | Business meaning, never type restatement |
| `example` | Always for primitives, strings, UUIDs, dates | Realistic; matches validation constraints |
| `requiredMode` | Always | `REQUIRED` for required fields, `NOT_REQUIRED` for optional. Never default. |
| `format` | Where applicable | `"uuid"`, `"date-time"`, `"date"`, `"email"`, `"uri"` |
| `minLength` / `maxLength` / `pattern` | Where applicable | Documented in the schema |

**Finite-value fields** (status, type, mode, …) MUST publish the full set of valid values — via `allowableValues` in `@Schema`, via a referenced enum, or enumerated in `description`. A finite-value field documented as a bare string is a violation. **[PR Review]**

### Enums

Document at the enum type with `@Schema(enumAsRef = true)`. Per-value `@Schema(description)` on each constant. Published enum values appear in `SCREAMING_SNAKE_CASE` per [`project-conventions.md`](project-conventions.md). **[PR Review]**

### Schemas that consumers cannot integrate against

The published schema MUST NOT contain opaque shapes. The following are violations of the published contract regardless of how they appear in source:

| Published shape | Why it fails |
|---|---|
| Property typed `object` with no further structure | Consumer cannot generate a typed client |
| Free-form map (no declared property names) | Consumer has no contract for keys |
| Polymorphic union without a discriminator | Consumer cannot tell variants apart |

**[PR Review]**

## Idempotency

Whether a mutating endpoint is idempotent — and how — is an **API-design choice per endpoint**, not something the convention prescribes. The documentation requirement is that the endpoint's `@Operation.description` truthfully describes its actual posture, so consumers know whether retries are safe. **[PR Review]**

Every mutating endpoint (`POST`, `PUT`, `PATCH`, `DELETE`) MUST document its idempotency posture. Depending on what the endpoint actually does:

| Posture | What `@Operation.description` MUST state |
|---|---|
| Idempotency-key protected | The header name; the actual retry window the implementation honours; how duplicates are detected; the response returned on a duplicate; the scope (per-principal, global, …) — match what the implementation actually does |
| Naturally idempotent (entity key / upsert) | Why the endpoint is naturally idempotent (the entity key that makes a retry harmless); the response returned on a no-op replay |
| **Not idempotent** | An explicit statement that retries may produce duplicate effects, so consumers can guard at their layer |

When the endpoint uses an idempotency-key header, the header itself MUST be declared as a documented `@Parameter` so it appears in the published spec. Realistic example value, actual retry window, and actual scoping behaviour:

```java
@Parameter(name = "Idempotency-Key", in = ParameterIn.HEADER, required = true,
    description = "Client-generated UUID. Window: 24h. Scoped to the authenticated principal — replays across users return 409.",
    example = "0190b8a4-0f8c-7c2a-9e6f-3d5b7e8f9a0b")
```

The above values (`24h`, principal scoping, 409 on cross-principal replay) reflect the **platform-recommended pattern** described in [`.claude/skills/idempotency/SKILL.md`](../skills/idempotency/SKILL.md). Services may implement different defaults — in which case the `@Parameter` and `@Operation.description` MUST reflect what the service actually does.

## Versioning & Deprecation

Breaking-change definition and `/api/v2/` rule live in [`engineering-principles.md`](engineering-principles.md).

Annotation requirements per deprecated endpoint:

| Marker | Where | Required |
|---|---|---|
| `@Operation(deprecated = true, description = "…")` | Method | Yes |
| Replacement endpoint + sunset date in `description` text | `@Operation.description` | Yes |
| `Deprecation` response header (RFC 8594) | `@ApiResponse(headers = …)` | Yes when scheduled for removal |
| `Sunset` response header (RFC 8594) | `@ApiResponse(headers = …)` | Yes when scheduled for removal |
| `Link: rel="successor-version"` header | `@ApiResponse(headers = …)` | Recommended |

**Sunset window:** the documented `Sunset` date MUST be at least 6 months after the documented `Deprecation` date. **[PR Review]**

## Bump.sh Requirements

### `info` block

| Field | Canonical content |
|---|---|
| `info.title` | `"{Service Display Name} API"` |
| `info.description` | Purpose-built per the rubric below — NOT a README copy |
| `info.contact.name` | `"{team-name}"` — identical across all services |
| `info.contact.email` | `"{team-email}"` — identical across all services |
| `info.version` | Present and non-empty (semver recommended) |
| `info.license` | **Omit** — the published spec MUST NOT carry an `info.license` block. |

All `info` fields above MUST be present and non-blank in the published spec. **[CI Gate]**

### `info.description` content rubric

Audience: **external integrators** opening Bump.sh for the first time. NOT a copy of the service `README.md`. Required content, in order:

1. **Business capability** — one sentence stating what business problem this API solves
2. **Primary integration use cases** — 1–2 sentences naming callers (mobile app, partner portal, back-office)
3. **Authentication** — one sentence describing the service's actual authentication posture: which scheme(s) (if any) it accepts, and whether it is internal-only or also reachable from external callers. Skip this sentence only if the service has no HTTP auth AND the README / network posture is explained elsewhere
4. **Platform contract notes** — short paragraph: error response shape (whichever the service uses); list endpoints are paginated (each endpoint documents its actual default and maximum page size in its own `description`); mutating endpoints idempotent
5. **Deprecation policy** — one sentence: *"Removed endpoints carry `Deprecation` and `Sunset` headers (RFC 8594) with a minimum 6-month sunset window."*
6. **Canonical docs link** — `docs/business/<domain>/`

Total length 4–8 sentences.

**Forbidden:** pasting the README, restating the title, mentioning Maven modules / package names / implementation classes, marketing language.

### Markdown rendering

Bump.sh renders Markdown, including headings (`##`), triple-backtick code fences, emoji, and any Unicode characters. Use whatever formatting makes the description clearest.

**Forbidden:** raw HTML. **[PR Review]**

### Sort order

Both top-level navigation lists in the published `openapi.yaml` MUST be sorted alphabetically. Bump.sh and Swagger UI both render in source order, so the published order IS the consumer experience.

| Element | Sort key | Notes |
|---|---|---|
| `tags[]` | `name`, ASCII ascending (Title Case) | Drives the Bump.sh side-navigation order. |
| `paths` map keys | URL path, ASCII ascending | Determines the order in which operations appear within each tag in Bump.sh. |
| `components.schemas` keys | Schema name, ASCII ascending | Stabilises the published spec; produces diff-friendly output across regenerations. |

Standard implementation: set `springdoc.writer-with-order-by-keys=true` in `application.properties` (sorts every Map-typed structure in the emitted spec — `paths`, `components.schemas`, `components.securitySchemes`, response/request `content` keys, …). The `tags[]` list is a Java `List`, not a Map, so it is **not** sorted by this property — services MUST also register an `OpenApiCustomizer` bean that sorts `openApi.getTags()` by name, OR declare the tags alphabetically in source. **[PR Review]**

### Cross-service consistency

| Element | Required value |
|---|---|
| `info.title` | `"{Service Display Name} API"` |
| `info.version` | Present, semver |
| `info.contact.email` | `"{team-email}"` |
| `servers[].description` | drawn from `stg`, `prd` — lowercase |
| Security scheme name (when the service uses JWT bearer) | `"bearerAuth"` |
| Tag naming | Title Case, plural noun |
| Error responses | Every response references a concrete schema (no empty `@Content`) |
| Pagination disclosure | Every paginated endpoint states its actual default + max page size in its `description`, matching the page-size `@Parameter` schema |

Drift = Blocker. **[PR Review]**

> The "Security scheme name" entry is a **naming convention** — when the service has a JWT-bearer scheme, it MUST be called `bearerAuth` for consistency across the platform. The convention does **not** require a service to have such a scheme.

### Terminology lock

When the same business concept appears in multiple endpoints, the wording MUST be identical. Canonical terms live in `docs/business/domain-glossary.md`. **[PR Review]**

## Trade-offs & Known Gaps

| Gap | Mitigation |
|---|---|
| `Page<T>` substitution requires explicit `@Content(array = @ArraySchema(...))` per list endpoint | See [Pagination](#pagination) |
| SpringDoc `oneOf` / `discriminator` polymorphism has known rendering issues on Bump.sh | Where rendering breaks, document the variants as separate response schemas |

## Examples

> Examples illustrate how the **documentation annotations** are arranged. Surrounding code (controller wiring, method bodies, framework integration) is shown for context only — this convention enforces only the documentation parts.

### Good — controller (canonical pattern)

```java
@Tag(name = "Orders", description = "Placement, retrieval, and lifecycle of customer orders.")
@SecurityRequirement(name = "bearerAuth")
@RestController
@RequestMapping("/v1/orders")
public class OrderController {

    @PostMapping
    @Secured("ROLE_CUSTOMER")
    @Operation(
        operationId = "placeOrder",
        summary     = "Place an order",
        description = """
            Places a new order for the items in the customer's basket.
            Requires `ROLE_CUSTOMER`; the principal must own the basket identified by `basketId`.

            **Idempotent** via `Idempotency-Key` header (24h window, scoped to principal).
            **On success:** emits `OrderPlacedEvent`; fulfilment is asynchronous.

            See `docs/business/orders/business-process.md`.
            """
    )
    @ApiResponse(responseCode = "201", description = "Order accepted.",
        content = @Content(schema = @Schema(implementation = OrderResponse.class)))
    @ApiResponse(responseCode = "401", description = "Unauthenticated.",
        content = @Content(mediaType = "application/problem+json",
                           schema = @Schema(ref = "#/components/schemas/ProblemDetail")))
    @ApiResponse(responseCode = "403", description = "Forbidden - missing role or ownership.",
        content = @Content(mediaType = "application/problem+json",
                           schema = @Schema(ref = "#/components/schemas/ProblemDetail")))
    @ApiResponse(responseCode = "409", description = "Basket already ordered or Idempotency-Key reused across users.",
        content = @Content(mediaType = "application/problem+json",
                           schema = @Schema(ref = "#/components/schemas/ProblemDetail")))
    public ResponseEntity<OrderResponse> placeOrder(
        @Parameter(name = "Idempotency-Key", in = ParameterIn.HEADER, required = true,
            description = "UUID v4. Window: 24h. Scoped to the authenticated principal.",
            example = "0190b8a4-0f8c-7c2a-9e6f-3d5b7e8f9a0b")
        @RequestHeader("Idempotency-Key") UUID idempotencyKey,

        @Valid @RequestBody PlaceOrderRequest request,

        @Parameter(hidden = true) @AuthenticationPrincipal AuthenticatedUser principal
    ) { ... }
}
```

### Good — DTO

```java
@Schema(description = "Response when an order is placed or queried.")
public record OrderResponse(

    @Schema(description = "Order number - the customer-facing unique identifier for the order.",
            example = "ORD-2024-00012345",
            requiredMode = Schema.RequiredMode.REQUIRED)
    String orderNumber,

    @Schema(description = "Current lifecycle state of the order.",
            example = "AWAITING_FULFILMENT",
            requiredMode = Schema.RequiredMode.REQUIRED)
    OrderStatus orderStatus
) { }
```

### Anti-patterns to reject in review

- `@Parameter(name = "Authorization", …)` on any endpoint
- `@ApiResponses({ @ApiResponse, @ApiResponse })` wrapper
- Error response with empty `@Content` or no schema reference
- DTO record with zero `@Schema` annotations
- Finite-value field documented as a bare string with no enumeration of valid values
- `info.description` copied from the README
- `example = "string"` / `"foo"` / `"123"`
- Missing or blank `info.version`
- `@JsonIgnore` used as a substitute for proper `@Schema(accessMode = …)` documentation
- Published schema property typed `object` with no further structure

---

## Appendix A — Reference: exception → status mapping

**Non-normative.** An illustrative mapping for services that wire up a global `@RestControllerAdvice` exception handler. It helps reviewers and authors figure out *which statuses an endpoint can actually return* so they can declare them in `@ApiResponse`. The convention itself (above) only requires that the **declared** statuses match what the **runtime** actually produces — derive the real mapping from your own exception handler.

| Status | Typical exceptions (Spring / Jakarta) |
|---|---|
| `400` | `IllegalArgumentException`, `MissingRequestHeaderException`, `MethodArgumentNotValidException`, `HandlerMethodValidationException`, `ConstraintViolationException`, `DataIntegrityViolationException` |
| `401` | `BadCredentialsException`, `AuthenticationCredentialsNotFoundException` |
| `403` | `AccessDeniedException` |
| `404` | `EntityNotFoundException`, your own `ResourceNotFoundException` |
| `409` | `EntityExistsException`, `OptimisticLockException` |
| `429` | your own rate-limit exception |
| `500` | `IllegalStateException`, any unmapped exception |
| upstream | HTTP-client exceptions (`RestClientResponseException`, `FeignException`, …) when the handler propagates the upstream status |
