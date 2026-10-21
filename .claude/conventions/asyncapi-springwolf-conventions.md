# AsyncAPI / SpringWolf Conventions

**Status:** Authoritative platform standard. The generated `asyncapi-v3.yaml` is the async contract; Bump.sh is the publication target. **Annotations on Java code are the single source of truth — hand-edited YAML is a Blocker.**

Every rule ends with **[Planning] / [Implementation] / [PR Review] / [CI Gate]**. Reviewer-runnable PR checklist lives in [`asyncapi-review-checklist.md`](asyncapi-review-checklist.md).

> **Placeholders:** values in `{braces}` such as `{team-email}` or `{base-package}` are defined once in `CLAUDE.md` → *Project Settings*. Always use the configured value; if a value is still *not set*, ask the user before writing it into code or docs.

## Purpose & Scope

How every async message contract in the platform documents itself through SpringWolf annotations. **Scope: SQS Standard Queues only.** FIFO, SNS, and Kafka are out of scope until adopted.

**Out of scope (covered elsewhere):**
- Consumer implementation rules (idempotency, error classification, DLQ, visibility timeout, tracing) → [`.claude/skills/async-consumers/SKILL.md`](../skills/async-consumers/SKILL.md)
- REST contracts → [`openapi-springdoc-conventions.md`](openapi-springdoc-conventions.md)
- Domain event publication semantics → [`.claude/skills/domain-driven-design/SKILL.md`](../skills/domain-driven-design/SKILL.md)

## Cross-references

- [`engineering-principles.md`](engineering-principles.md) — idempotency, API evolution
- [`architecture-standards.md`](architecture-standards.md) — data consistency, transactional boundaries
- [`definition-of-done.md`](definition-of-done.md) — pre-merge checklist
- [`openapi-springdoc-conventions.md`](openapi-springdoc-conventions.md) — sibling REST convention
- [`.claude/skills/async-consumers/SKILL.md`](../skills/async-consumers/SKILL.md) — consumer implementation rules (out of scope here)
- [`.claude/skills/idempotency/SKILL.md`](../skills/idempotency/SKILL.md)

## Tooling

| Rule | Tag |
|---|---|
| Every service that publishes or consumes SQS messages MUST produce a complete `asyncapi-v3.yaml`. | **[CI Gate]** |
| The published `asyncapi-v3.yaml` MUST be machine-generated from annotations — hand-edits are a Blocker. | **[CI Gate]** |
| The async documentation endpoint (`/springwolf/docs.yaml`) MUST be reachable in deployed environments. | **[CI Gate]** |
| `springwolf.enabled=true`, `springwolf.docket.base-package={base-package}.<service-name>`, and the full `springwolf.docket.info.*` and `springwolf.docket.servers.sqs-server.*` block MUST be set in `application.properties`. Missing `docket` or `base-package` causes SpringWolf to fail context initialisation. | **[CI Gate]** |
| The same `springwolf.*` block MUST also be present, with identical values, in `src/test/resources/application.properties`. Spring Boot's test classpath replaces — does not merge with — the main `application.properties`, so the doc-generation test (which writes the published spec) reads only the test copy. | **[CI Gate]** |

## Core Models

### Channel naming

| Rule | Tag |
|---|---|
| The AsyncAPI channel name in the published spec MUST equal the underlying SQS queue name exactly — no env stripping, no rewriting. | **[CI Gate]** |

How SQS queues themselves are named, versioned, and twinned with DLQs is **infrastructure policy**, not a documentation rule. See [Appendix A](#appendix-a--reference-sqs-queue-naming-convention) for an example naming scheme — non-normative, included only to help reviewers verify that a published channel name follows whatever scheme the platform adopts.

### Headers Contract

The published spec MUST document **every header actually on the wire** for each operation. The convention does not prescribe which headers a service implementation injects; it only governs how those headers are documented.

| Rule | Tag |
|---|---|
| Every header actually present on a message MUST be documented in `@AsyncOperation.Headers` with `name`, `description`, and a realistic `value` example. | **[CI Gate]** |
| The published spec MUST NOT document headers that the implementation does not actually inject — phantom headers are worse than missing ones. | **[PR Review]** |
| Header names in the published spec MUST be `lower-kebab-case`. | **[PR Review]** |

**Typical headers on the wire** for a Spring Cloud AWS + Micrometer Tracing stack (services using a different messaging stack document whatever they actually emit):

| Header | Purpose | Example value |
|---|---|---|
| `traceparent` | W3C Trace Context propagation. Format: `00-{32-hex-traceId}-{16-hex-spanId}-{2-hex-flags}`. | `00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01` |
| `id` | SQS-assigned MessageId, exposed by Spring messaging as the `id` header. Consumers use it as the deduplication key. Max 36 chars (UUID with hyphens). | `1e33caca-e9cc-4d70-af04-965bf144a43c` |

> **Do not document headers that merely sound plausible** (`event-version`, `producer-service`, `correlationId`, `idempotency-id`, …) unless your send path actually injects them. If your service emits its own additional headers, document those.

### Trust Boundary & Security

Every channel's `@AsyncOperation.description` MUST state its trust boundary. If a channel has external publishers or consumers, they MUST be listed in the description.

**Trust boundary statement** — required verbatim in `@AsyncOperation.description`:

| Posture | Required text |
|---|---|
| Internal-only (default) | *"Trust boundary: internal SQS. Only platform services may publish or consume."* |
| Internal + named external | *"Trust boundary: internal SQS. Producers: {service}. Consumers: {service}, [external-X — see docs/security/<domain>/security-permissions.md]."* |
| Cross-account | *"Trust boundary: cross-account SQS. See docs/security/<domain>/security-permissions.md."* |

Every channel's `@AsyncOperation.description` MUST also list the producer service(s) and consumer service(s) by name. **[PR Review]**

**PII in messages:**

| Rule | Tag |
|---|---|
| Every PII field MUST be marked `@Schema(description = "PII - <classification> - <reason>")`. | **[PR Review]** |
| PII examples use the fictitious-values rules from [`openapi-springdoc-conventions.md`](openapi-springdoc-conventions.md#security-model--documentation-rules). | **[PR Review]** |
| Published `info.description` MUST state that SQS message bodies are KMS-encrypted at rest and link to `docs/security/<domain>/security-permissions.md`. | **[PR Review]** |

**Audit fields** — where the event carries any of the following, each field MUST be documented per the standard `@Schema` rules:

| Field | Notes |
|---|---|
| `producerService` | Producer service name |
| `producedAt` | Production timestamp (ISO-8601 UTC) |
| `eventId` | Unique event instance |
| `actorId` | Authenticated principal who triggered the action. MUST be marked as PII in `@Schema.description` when present. |

Headers `traceparent` and `id` are documented separately in [Headers Contract](#headers-contract).

### Idempotency, Ordering, Delivery

Whether a queue is STANDARD or FIFO, what deduplicates messages, where failures end up, how many retries happen before a message goes to the DLQ — these are **infrastructure / implementation choices per channel**, not convention rules. The documentation requirement is that the operation description states these facts **truthfully**.

Every `@AsyncOperation.description` MUST cover, in prose, all of:

| Fact | What to state |
|---|---|
| Delivery semantics | At-least-once / exactly-once / best-effort — whichever the channel actually provides |
| Deduplication | How the consumer dedupes (SQS MessageId, domain-level key, natural uniqueness, …) — or that no dedup is performed |
| Queue ordering | Ordered (FIFO) / unordered (STANDARD) |
| Latency / throughput | Measured envelopes when known; `"not measured"` when not. Silent omission is a Blocker. |
| Failure routing | Where failures go (DLQ name when present, or "no DLQ — failed messages are retained on the source queue / dropped / …") and the redrive policy (e.g. *"after 3 receive attempts"*) |

**[PR Review]**

**Recommended template wording** — services whose channel actually matches the description below MAY use these sentences verbatim. Services whose implementation differs MUST adapt the wording to reflect reality.

| Fact | Template (use verbatim when accurate) |
|---|---|
| Idempotency + delivery (SQS Standard + MessageId-based dedup) | *"At-least-once delivery; consumer is idempotent via the SQS MessageId used as deduplication key."* |
| Queue type (SQS Standard) | *"Queue type: STANDARD (unordered). Expected p99 latency: `{value}`. Throughput envelope: `{value}`."* |
| DLQ (standard 3-attempt redrive) | *"Failures are routed to `{dlq-name}` after 3 receive attempts."* |

Drift between the prose and the actual channel behaviour is a Blocker. **[PR Review]**

> SpringWolf does not render DLQ topology natively — it lives in the description prose until SpringWolf supports it.

## Listener Rules (Consumers)

| Requirement | Tag |
|---|---|
| Every `@SqsListener` method MUST carry `@AsyncListener`. Missing = the operation is absent from the published spec. | **[CI Gate]** |
| `payloadType` set explicitly on the annotation. The published `messages` block must always carry a fully-qualified `payloadType`. | **[PR Review]** |

### `@AsyncOperation` required attributes

| Attribute | Required | Content |
|---|---|---|
| `channelName` | Yes | Equal to the SQS queue name (see [Channel & Queue Naming](#channel-naming)) |
| `description` | Yes | 2–4 sentences — business meaning, trigger, postconditions, plus the facts required by [Idempotency, Ordering, Delivery](#idempotency-ordering-delivery) and the trust-boundary statement from [Trust boundary](#trust-boundary--security) |
| `payloadType` | Yes | The payload class set as an explicit `.class` reference on the annotation |
| `headers` | Yes | `@AsyncOperation.Headers` covering every header per [Headers Contract](#headers-contract) |
| `message` (`@AsyncMessage`) | Only when multiple message types on the same channel | `name`, `title`, `description`, `contentType = "application/json"` |

## Publisher Rules

| Requirement | Tag |
|---|---|
| Every public publish method MUST carry `@AsyncPublisher`. Missing = the operation is absent from the published spec. | **[CI Gate]** |
| `payloadType` set explicitly on the annotation. | **[PR Review]** |
| Header `value` examples MUST be realistic (UUIDs for IDs, semver for versions) — never `"string"` / `"123"`. | **[PR Review]** |

`@AsyncOperation` attributes are identical to the listener side (see table above). Both `traceparent` and `id` headers apply to publisher operations in the same way.

## Event Schema Rules

### Class-level `@Schema`

Every event record MUST carry `@Schema(description = …)` covering, in order:

1. **Business meaning** — what real-world fact does this event assert?
2. **Trigger condition** — exactly when does the producer emit it?
3. **Consumer expectations** — what consumers should do; delivery + ordering guarantees; canonical business-doc link.

**[PR Review]**

### Field-level `@Schema`

Same rules as REST DTOs ([`openapi-springdoc-conventions.md`](openapi-springdoc-conventions.md#schema-rules)). Every component:

| Attribute | Required | Rule |
|---|---|---|
| `description` | Always | Business meaning, never type restatement |
| `example` | Always for primitives, strings, UUIDs, dates | Realistic |
| `requiredMode` | Always | `REQUIRED` or `NOT_REQUIRED`. Never default. |
| `format` | Where applicable | `"uuid"`, `"date-time"`, etc. |

**Finite-value fields** (status, type, mode, …) MUST publish the full set of valid values — via `allowableValues` in `@Schema`, via a referenced enum, or enumerated in `description`. **[PR Review]**

### Schemas that consumers cannot integrate against

The published payload schema MUST NOT contain opaque shapes:

| Published shape | Why it fails |
|---|---|
| Property typed `object` with no further structure | Consumer cannot generate a typed payload |
| Free-form map (no declared property names) | Consumer has no contract for keys |
| "Reserved-for-future-use" JSON blobs | Add fields explicitly per [Versioning](#versioning--evolution) |

**[PR Review]**

PII rules: see [Trust Boundary & Security](#trust-boundary--security).

## Versioning & Evolution

| Rule | Tag |
|---|---|
| The published schema for a given event class MUST NOT change in a breaking way. Breaking changes (removing, renaming, retyping, or re-meaning a field; or making an optional field required) require a **new event class** with its own published schema. | **[PR Review]** |
| Adding an optional field (`requiredMode = NOT_REQUIRED`) is non-breaking; no new event class needed. | **[PR Review]** |
| During a breaking transition, both versions appear in the published spec as distinct operations; the deprecated event class carries `@Schema(deprecated = true)`. | **[PR Review]** |

### Deprecation marker

```java
@Schema(deprecated = true,
        description = "DEPRECATED. Superseded by CustomerRegisteredEventV2 on APP-CustomerRegisteredV2-prd. " +
                      "Drain target: 2026-06-01.")
public record CustomerRegisteredEvent(...) { }
```

A deprecated event MUST carry a removal target date (ISO-8601) in the description. **[PR Review]**

## Bump.sh Requirements

### `info` block

| Field | Canonical content |
|---|---|
| `info.title` | `"{Service Display Name} Async API"` |
| `info.description` | Purpose-built per the rubric below — NOT a README copy |
| `info.contact.email` | `"{team-email}"` — identical across all services |
| `info.version` | Present and non-empty; same as OpenAPI |

All `info` fields above MUST be present and non-blank in the published spec. **[CI Gate]**

### `info.description` content rubric

Audience: **external integrators and internal operators**. NOT a README copy. Required content, in order:

1. **Business surface** — one sentence stating what business state changes this service participates in via async messaging
2. **Events published** — bullet list: event class + one-phrase business meaning
3. **Events consumed** — bullet list: event class + one-phrase business meaning
4. **Trust boundary** — one sentence (use the verbatim form from [Trust Boundary](#trust-boundary--security))
5. **Platform contract notes** — short paragraph describing the service's actual async posture: delivery semantics, dedup mechanism, header set, encryption-at-rest, failure-routing policy. Reflect what the implementation actually does — do not copy a template without checking
6. **Versioning** — one sentence stating that breaking changes appear as new event classes on new channels
7. **Canonical docs link** — `docs/business/<domain>/`

Length 5–10 sentences plus bullet lists.

**Forbidden:** pasting the README, restating the title, mentioning Maven modules / package names / implementation classes, marketing language.

### Server entries

| Element | Required value |
|---|---|
| Server key | `sqs-server` (literal) |
| `protocol` | `sqs` (literal) |
| `host` | `https://sqs.{aws-region}.amazonaws.com` (or the region the queue actually lives in) |
| `description` | One sentence stating environment + AWS region + queue prefix, e.g. *"AWS SQS — production, eu-west-1. Queue prefix: APP-, environment suffix: -prd."* (using the configured `{aws-region}` and `{queue-prefix}`) |

**[PR Review]**

### Markdown rendering

Bump.sh renders Markdown. Use bullets, `` `inline code` ``, **bold**, tables.

**Forbidden:** raw HTML, heading syntax inside descriptions, triple-backtick code fences inside descriptions, emoji.

### Sort order

Both top-level navigation maps in the published `asyncapi-v3.yaml` MUST be sorted alphabetically. Bump.sh renders in source order, so the published order IS the consumer experience.

| Element | Sort key | Notes |
|---|---|---|
| `channels` map | Channel name (= SQS queue name), ASCII ascending | Drives the Bump.sh side-navigation order. |
| `operations` map | Operation key (= operationId, `{Verb}{Noun}`), ASCII ascending | Stabilises the published spec; produces diff-friendly output across regenerations. |
| `components.schemas` map | Schema name, ASCII ascending | Same diff-friendliness rationale. |

SpringWolf has no built-in alphabetical-output flag. Services MUST register an `AsyncApiCustomizer` bean (or equivalent) that sorts `channels`, `operations`, and `components.schemas` by key. Until that is in place, ordering the `@AsyncListener` / `@AsyncPublisher` source declarations alphabetically is an acceptable interim measure for services with only one or two operations. **[PR Review]**

### Cross-service consistency

| Element | Required value |
|---|---|
| `info.title` | `"{Service Display Name} Async API"` |
| `info.version` | Same as OpenAPI |
| `info.contact.email` | `"{team-email}"` |
| `servers.sqs-server.protocol` | `sqs` |
| Server key | `sqs-server` |
| Channel name | Equal to the underlying SQS queue name, verbatim — published name matches the resource name |
| Operation ID | `{Verb}{Noun}` (e.g. `ReceiveCustomerRegistered`, `SendOrderShipped`) |
| Message ID | Simple class name of the event record |
| Idempotency / delivery / DLQ disclosure | Every operation description states the actual delivery semantics, dedup mechanism, ordering, latency/throughput envelope, and failure-routing posture — matching the channel's real behaviour ([Idempotency, Ordering, Delivery](#idempotency-ordering-delivery)) |
| Header naming | Every header actually emitted is documented, in `lower-kebab-case`. Typically `traceparent` + `id` on a Spring Cloud AWS + Micrometer Tracing stack. |

Drift = Blocker. **[PR Review]**

### Terminology lock

Same business concept worded identically across events. Canonical terms: `docs/business/domain-glossary.md`. **[PR Review]**

## Trade-offs & Known Gaps

| Gap | Mitigation / status |
|---|---|
| `/springwolf/docs.yaml` not exposed in a deployed environment | Bump.sh publication is blocked for that service until the endpoint is reachable |
| `payloadType` reflection produces ambiguous Bump.sh rendering when services share like-named events | Always set `payloadType = X.class` explicitly on the operation |
| SpringWolf does not render DLQ topology as first-class channel links | DLQ named in `@AsyncOperation.description` prose |
| `actorId` policy not standardised | Each event documents its own choice in `@Schema` |

## Examples

> Examples illustrate how the **documentation annotations** are arranged. Surrounding code (base classes, method bodies, framework wiring) is shown for context only — this convention enforces only the documentation parts.

### Good — event record

```java
@Schema(description = """
    Asserts that a new customer account has been registered.

    Emitted once per customerId, immediately after the registration
    transaction commits.

    Consumers provision dependent resources (preferences, welcome email).
    Delivery: at-least-once. Consumers must be idempotent on `customerId`.

    See `docs/business/customers/business-process.md`.
    """)
public record CustomerRegisteredEvent(
    @Schema(description = "Customer identifier. Stable, internal UUID. Use as dedup key.",
            example = "0190b8a4-0f8c-7c2a-9e6f-3d5b7e8f9a0b",
            format = "uuid",
            requiredMode = Schema.RequiredMode.REQUIRED)
    UUID customerId
) { }
```

### Good — publisher

```java
@Component
@RequiredArgsConstructor
public class CustomerRegisteredPublisher {

    private final SqsTemplate sqsTemplate;

    @Value("${app.sqs.customer-registered-queue}")
    private String queue;

    @AsyncPublisher(operation = @AsyncOperation(
        channelName = "${app.sqs.customer-registered-queue}",
        description = """
            Emitted immediately after a customer registration commits to the source database.
            Fires once per customerId.

            Trust boundary: internal SQS. Producer: customer-service. Consumers: notification-service.
            At-least-once delivery; consumer is idempotent via the SQS MessageId used as deduplication key.
            Queue type: STANDARD (unordered). Expected p99 latency: < 5s. Throughput envelope: up to 100 msg/s sustained.
            Failures are routed to APP-CustomerRegistered-{env}-dlq after 3 receive attempts.
            """,
        payloadType = CustomerRegisteredEvent.class,
        headers = @AsyncOperation.Headers(
            schemaName = "CustomerRegisteredHeaders",
            values = {
                @AsyncOperation.Headers.Header(name = "traceparent",
                    description = "W3C Trace Context propagation header injected by Micrometer OTel. " +
                                  "Format: 00-{32-hex-traceId}-{16-hex-spanId}-{2-hex-flags}.",
                    value = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"),
                @AsyncOperation.Headers.Header(name = "id",
                    description = "SQS-assigned MessageId used as the deduplication key by the consumer.",
                    value = "1e33caca-e9cc-4d70-af04-965bf144a43c")
            }
        )
    ))
    public void publish(CustomerRegisteredEvent event) {
        sqsTemplate.send(queue, event);
    }
}
```

### Good — consumer

```java
@Slf4j
@Component
@RequiredArgsConstructor
class OrderFulfilmentConsumer {

    private final OrderFulfilmentHandler handler;

    @AsyncListener(operation = @AsyncOperation(
        channelName = "${app.sqs.order-fulfilment-queue}",
        description = """
            Consumes OrderFulfilmentRequested to start picking and shipping for a placed order.

            Trust boundary: internal SQS. Producer: order-service. Consumer: fulfilment-service.
            At-least-once delivery; consumer is idempotent via the SQS MessageId used as deduplication key.
            Queue type: STANDARD (unordered). Expected p99 latency: < 5s. Throughput envelope: up to 200 msg/s.
            Failures are routed to APP-OrderFulfilment-{env}-dlq after 3 receive attempts.
            """,
        payloadType = OrderFulfilmentRequested.class,
        headers = @AsyncOperation.Headers(
            schemaName = "OrderFulfilmentHeaders",
            values = {
                @AsyncOperation.Headers.Header(name = "traceparent",
                    description = "W3C Trace Context propagation header injected by Micrometer OTel. " +
                                  "Format: 00-{32-hex-traceId}-{16-hex-spanId}-{2-hex-flags}.",
                    value = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"),
                @AsyncOperation.Headers.Header(name = "id",
                    description = "SQS-assigned MessageId used as the deduplication key by the consumer.",
                    value = "1e33caca-e9cc-4d70-af04-965bf144a43c")
            }
        )
    ))
    @SqsListener("${app.sqs.order-fulfilment-queue}")
    public void consume(Message<OrderFulfilmentRequested> message) {
        handler.handle(message.getHeaders().getId(), message.getPayload());
    }
}

// Payload schema documented by the consumer
@Schema(description = "Request to fulfil a placed order.")
public record OrderFulfilmentRequested(
    @Schema(description = "Order identifier.",
            example = "0190b8a4-0f8c-7c2a-9e6f-3d5b7e8f9a0b",
            format = "uuid", requiredMode = Schema.RequiredMode.REQUIRED) UUID orderId,
    @Schema(description = "Number of line items in the order.", example = "3",
            requiredMode = Schema.RequiredMode.REQUIRED) int lineItemCount,
    @Schema(description = "Requested shipping speed.", example = "EXPRESS",
            allowableValues = {"STANDARD", "EXPRESS"},
            requiredMode = Schema.RequiredMode.REQUIRED) String shippingSpeed
) { }
```

### Anti-patterns to reject in review

- `@SqsListener` method without `@AsyncListener` (operation absent from published spec)
- Public SQS publish method without `@AsyncPublisher` (operation absent from published spec)
- Event record with no class-level `@Schema`
- Event field with no `@Schema(description, example, requiredMode)`
- Finite-value field documented as a bare string with no enumeration of valid values
- Published payload schema with `object`-typed properties or free-form maps
- Missing trust-boundary statement in operation description
- Operation description silent on delivery semantics, dedup mechanism, queue ordering, or failure routing (or, worse, stating a value that doesn't match the actual channel)
- `payloadType` left implicit
- AsyncAPI channel name in the published spec that does not match the SQS queue name
- PII field present but not marked as PII in `@Schema.description`
- Hand-edited `target/asyncapi-v3.yaml`
- `info.description` copied from the README
- No live `/springwolf/docs.yaml` endpoint in deployed environments (Bump.sh has nothing to publish)

---

## Appendix A — Reference: SQS queue naming convention

**Non-normative.** An example naming scheme for SQS resources, using the configured `{queue-prefix}` (`APP` in the examples), included to help reviewers verify that a channel name in the published spec looks right. Queue naming itself is infrastructure policy, not a documentation rule — services that legitimately use a different scheme (legacy queues, externally-owned queues, cross-account topology, …) document whatever the channel is actually called.

| Resource | Format | Example |
|---|---|---|
| Source queue | `{queue-prefix}-{DomainContextCamelCase}-{environment}` | `APP-OrderProcessing-prd` |
| DLQ | `{queue-name}-dlq` | `APP-OrderProcessing-prd-dlq` |
| Versioned queue | `{queue-prefix}-{DomainContext}V{N}-{environment}` | `APP-CustomerRegisteredV2-prd` |
