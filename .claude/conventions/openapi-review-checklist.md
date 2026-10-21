# OpenAPI PR Review Checklist

Run on every PR that introduces or modifies a REST endpoint, DTO, or `OpenApiConfig`. The full rules and rationale live in [`openapi-springdoc-conventions.md`](openapi-springdoc-conventions.md). This document is the **scan-and-tick** companion.

> **Placeholders:** values in `{braces}` such as `{team-email}` or `{base-package}` are defined once in `CLAUDE.md` → *Project Settings*. Always use the configured value; if a value is still *not set*, ask the user before writing it into code or docs.

Each item is tagged with its enforcement point: **[PR Review]** = reviewer-checked; **[CI Gate]** = automated.

## Controller structure

- [ ] `@Tag` on the controller; `name` is Title Case plural business noun; matches `docs/business/<domain>/` — **[PR Review]**
- [ ] Tag registered in `@OpenAPIDefinition.tags` — **[PR Review]**
- [ ] Operations reference the security scheme they actually accept (e.g. `@SecurityRequirement(name = "bearerAuth")`) when the service defines one; operations that opt out of a global default explicitly declare `@SecurityRequirements({})`. The published security requirements MUST match runtime behaviour — **[PR Review]**
- [ ] No per-endpoint `@Parameter(name = "Authorization", …)` — security schemes belong in `components.securitySchemes`, not as parameters — **[CI Gate]**

## Operation

- [ ] `@Operation.summary` ≤ 60 chars, imperative, no trailing period — **[PR Review]**
- [ ] `@Operation.description` 2–6 sentences: what / when / preconditions / postconditions / side effects — **[PR Review]**
- [ ] `@Operation.operationId` camelCase, stable, globally unique within the service — **[PR Review]**
- [ ] Description states required role(s) on secured endpoints — **[PR Review]**
- [ ] No method-name restatement, no vague verbs ("handles", "processes", "manages") — **[PR Review]**
- [ ] Acronyms expanded on first use — **[PR Review]**
- [ ] Description links to `docs/business/<domain>/`; if missing, a follow-up story ticket is filed — **[Planning] [PR Review]**

## Responses

- [ ] Multiple `@ApiResponse` annotations stacked directly on the method — **no `@ApiResponses({ … })` wrapper** (SonarQube flag) — **[CI Gate]**
- [ ] Every status the endpoint can produce is documented — **[PR Review]**
- [ ] No status is documented that the endpoint cannot produce — **[PR Review]**
- [ ] Every non-2xx response references a concrete schema (no empty `@Content`) — **[CI Gate]**
- [ ] `description` per response = business condition, not HTTP semantic — **[PR Review]**
- [ ] Auth-failure statuses (`401`, `403`) declared as the runtime actually returns them — **[PR Review]**
- [ ] `429` documented where rate limiting applies — **[PR Review]**

## Parameters & request body

- [ ] Every `@PathVariable`, `@RequestParam`, `@RequestHeader` (excluding `Authorization`) has `@Parameter` with `name`, `description`, `required` (explicit), `example` — **[PR Review]**
- [ ] Examples are realistic — no `"string"`, `"foo"`, `"123"` — **[CI Gate]**
- [ ] `hidden = true` only on parameters that are server-injected (not client-supplied) — **[PR Review]**
- [ ] Custom headers (`Idempotency-Key`, correlation IDs) documented as `@Parameter(in = ParameterIn.HEADER, …)` — **[Implementation]**
- [ ] Request body documented with `@io.swagger.v3.oas.annotations.parameters.RequestBody` — **[Implementation]**

## DTOs & schemas

- [ ] Every DTO record / class has a class-level `@Schema(description)` — **[PR Review]**
- [ ] Every field has `description` + `example` + `requiredMode` — **[PR Review]**
- [ ] `format` documented where applicable (`"uuid"`, `"date-time"`, `"email"`) — **[PR Review]**
- [ ] Length / pattern constraints documented in the schema (`minLength`, `maxLength`, `pattern`) — **[PR Review]**
- [ ] Finite-value fields publish all valid values (`allowableValues`, enum reference, or enumerated in `description`) — **[PR Review]**
- [ ] Enums published with `@Schema(enumAsRef = true)` + per-value `@Schema(description)` — **[PR Review]**
- [ ] No `object`-typed properties without further structure in the published schema — **[PR Review]**
- [ ] Polymorphic responses publish a discriminator (`oneOf` + `discriminatorProperty`) — **[PR Review]**

## Pagination

- [ ] `page`, page-size (`size` / `pageSize` / service-local name), `sort` documented as `@Parameter` with realistic examples — **[PR Review]**
- [ ] Page-size `@Parameter` schema declares the endpoint's actual `defaultValue`, `minimum`, and `maximum` — **[PR Review]**
- [ ] Endpoint description states the endpoint is paginated AND gives the actual default + max page size — values MUST match the page-size `@Parameter` schema — **[PR Review]**
- [ ] `200` response uses `@Content(array = @ArraySchema(schema = @Schema(implementation = T.class)))` — **[CI Gate]**
- [ ] `sort` description enumerates sortable fields when not all fields are sortable — **[PR Review]**

## Idempotency

- [ ] Every mutating endpoint's `@Operation.description` truthfully states its idempotency posture — key-protected, naturally idempotent, OR explicitly not idempotent — **[PR Review]**
- [ ] For key-protected endpoints: the retry window, duplicate-call behaviour, and scoping rules match the implementation — **[PR Review]**
- [ ] For not-idempotent endpoints: the description explicitly warns that retries may produce duplicate effects — **[PR Review]**
- [ ] When the endpoint uses an idempotency-key header, the header is declared as a documented `@Parameter` with realistic example, actual window, and actual scoping behaviour — **[PR Review]**

## Security & PII

- [ ] No secrets in any response DTO (passwords, tokens, API keys, identity-provider session IDs) — **[PR Review]**
- [ ] No operationally irrelevant PII — **[PR Review]**
- [ ] PII fields marked `"PII — data classification: …"` in `description` — **[PR Review]**
- [ ] PII examples are clearly fictitious (use the canonical values from the convention) — **[PR Review]**
- [ ] Write-only fields use `@Schema(accessMode = Schema.AccessMode.WRITE_ONLY)` — **[Implementation]**
- [ ] Read-only fields use `@Schema(accessMode = Schema.AccessMode.READ_ONLY)` — **[Implementation]**
- [ ] `@JsonIgnore` NOT used as "documentation" for sensitive fields — **[PR Review]**

## Versioning & deprecation

- [ ] Deprecated endpoint carries all three: `@Operation(deprecated = true)`, `@Deprecated(forRemoval = true)`, replacement + sunset date in `description` — **[PR Review]**
- [ ] `Deprecation` and `Sunset` response headers documented via `@ApiResponse(headers = …)` — **[Implementation]**
- [ ] Documented `Sunset` date is ≥ 6 months after the documented `Deprecation` date — **[PR Review]**

## `OpenApiConfig`

- [ ] `components.securitySchemes` mirrors what the service actually accepts at runtime (zero, one, or several entries). When a JWT-bearer scheme is declared, it is named `bearerAuth` — **[PR Review]**
- [ ] `info.title` follows `"{Service Display Name} API"` — **[PR Review]**
- [ ] `info.version` present and non-empty — **[CI Gate]**
- [ ] `info.contact.email` = the shared team address (`"{team-email}"`), identical across services — **[PR Review]**
- [ ] Each `servers[].description` is one of `stg`, `prd` — lowercase — **[PR Review]**
- [ ] No service-local redefinition of `ProblemDetail`, `Page`, `Pageable`, `Sort` — **[CI Gate]**

## `info.description`

- [ ] NOT a copy of the README — **[PR Review]**
- [ ] Covers business capability / use cases / authentication (describe the service's actual posture, or skip if none and explained elsewhere) / platform contract / deprecation / canonical docs link — **[PR Review]**
- [ ] 4–8 sentences total — **[PR Review]**
- [ ] No implementation-class / Maven-module mentions — **[PR Review]**
- [ ] No marketing language, no emoji, no raw HTML — **[PR Review]**

## Consistency

- [ ] Same business concept worded identically across endpoints (cross-check `docs/business/domain-glossary.md`) — **[PR Review]**
- [ ] New domain terms added to the Domain Glossary — **[PR Review]**
- [ ] No drift between tag name and `docs/business/<domain>/` directory name — **[PR Review]**
- [ ] `springdoc.writer-with-order-by-keys=true` set in main + test `application.properties` (sorts `paths`, `components.schemas`, etc. alphabetically) — **[CI Gate]**
- [ ] Published `tags[]` are sorted alphabetically by `name` (ASCII ascending, Title Case) — via an `OpenApiCustomizer` bean or alphabetical source declarations — **[PR Review]**
- [ ] Published `paths` keys appear in alphabetical order in `target/openapi.yaml` (a direct consequence of `writer-with-order-by-keys`) — **[PR Review]**

## Build & publication

- [ ] Published `openapi.yaml` is machine-generated — no hand-edits — **[CI Gate]**
- [ ] `springdoc.packages-to-scan={base-package}.<service-name>` set in `src/main/resources/application.properties`; published spec contains only this service's endpoints — **[CI Gate]**
- [ ] `springdoc.packages-to-scan` ALSO set, with the same value, in `src/test/resources/application.properties` — the doc-generation test reads only the test classpath copy — **[CI Gate]**
