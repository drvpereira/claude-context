# AsyncAPI PR Review Checklist

Run on every PR that introduces or modifies a consumer, publisher, event record, or `SpringWolfConfig`. Full rules live in [`asyncapi-springwolf-conventions.md`](asyncapi-springwolf-conventions.md). This document is the **scan-and-tick** companion.

> **Placeholders:** values in `{braces}` such as `{team-email}` or `{base-package}` are defined once in `CLAUDE.md` → *Project Settings*. Always use the configured value; if a value is still *not set*, ask the user before writing it into code or docs.

Each item is tagged with its enforcement point: **[PR Review]** = reviewer-checked; **[CI Gate]** = automated.

## Published spec — `info` block

- [ ] `/springwolf/docs.yaml` endpoint reachable in deployed environments — **[CI Gate]**
- [ ] Published spec scoped to this service's events only (no foreign events leaking in) — **[PR Review]**
- [ ] Published `info.title` follows `"{Service Display Name} Async API"` — **[PR Review]**
- [ ] Published `info.version` is present and non-empty; matches OpenAPI version — **[CI Gate]**
- [ ] Published `info.contact.email` is the shared team address (`"{team-email}"`) — **[PR Review]**

## Published spec — servers

- [ ] Server key is `sqs-server` — **[PR Review]**
- [ ] `protocol` is `sqs`; `host` is `https://sqs.{aws-region}.amazonaws.com` (or the queue's actual region) — **[PR Review]**
- [ ] Server `description` states env + region + queue prefix — **[PR Review]**

## Annotations (mandatory)

- [ ] Every `@SqsListener` method has `@AsyncListener` — **[CI Gate]**
- [ ] Every public SQS publish method has `@AsyncPublisher` — **[CI Gate]**
- [ ] `payloadType` set explicitly on every operation — **[PR Review]**
- [ ] Every header actually present on the wire is documented in `@AsyncOperation.Headers` — on a Spring Cloud AWS + Micrometer Tracing stack this is typically `traceparent` and `id`; services using a different stack document whatever they emit — **[CI Gate]**
- [ ] No phantom headers: nothing in `@AsyncOperation.Headers` that the implementation does not actually inject — **[PR Review]**
- [ ] Header `value` examples realistic — no `"string"`, `"123"` — **[PR Review]**
- [ ] Header naming in the published spec is `lower-kebab-case` — **[PR Review]**

## Operation description

- [ ] Business meaning / trigger / postconditions stated (2–4 sentences) — **[PR Review]**
- [ ] Trust boundary statement present (verbatim form) — **[PR Review]**
- [ ] Producer service and consumer service(s) listed in description — **[PR Review]**
- [ ] Delivery semantics stated (at-least-once / exactly-once / best-effort) — matches the channel's real behaviour — **[PR Review]**
- [ ] Dedup mechanism stated (SQS MessageId / domain-level key / natural uniqueness / "no dedup performed") — matches what the consumer actually does — **[PR Review]**
- [ ] Queue ordering stated (STANDARD/unordered or FIFO/ordered) — matches the underlying queue — **[PR Review]**
- [ ] Latency / throughput envelope stated, OR `"not measured"` — silent omission is a Blocker — **[PR Review]**
- [ ] Failure routing stated — DLQ name (when present) and redrive policy — matches the actual infrastructure — **[PR Review]**
- [ ] Description links to `docs/business/<domain>/`; if missing, follow-up story ticket filed — **[Planning] [PR Review]**

## Event records

- [ ] Class-level `@Schema(description = …)` covers business meaning / trigger / consumer expectations — **[PR Review]**
- [ ] Every field has `description` + `example` + `requiredMode` — **[PR Review]**
- [ ] `format` documented where applicable (`"uuid"`, `"date-time"`) — **[PR Review]**
- [ ] Finite-value fields publish all valid values (`allowableValues`, enum reference, or enumerated in `description`) — **[PR Review]**
- [ ] No `object`-typed properties or free-form maps in the published payload schema — **[PR Review]**
- [ ] PII fields marked `"PII — data classification: …"` with classification — **[PR Review]**
- [ ] PII examples are clearly fictitious — **[PR Review]**

## Channel & queue naming

- [ ] AsyncAPI channel name in the published spec equals the underlying SQS queue name exactly — **[CI Gate]**
- [ ] Operation ID follows `{Verb}{Noun}` and is unique within the service — **[PR Review]**
- [ ] Message ID matches the event record's simple class name — **[PR Review]**

> Queue and DLQ resource naming is infrastructure policy, not a documentation rule. An example scheme (`{queue-prefix}-{DomainContext}-{env}` for source queues; `{queue-name}-dlq` for DLQs) is documented as informational in the AsyncAPI convention's Appendix A.

## Versioning

- [ ] Additive change: new field is `NOT_REQUIRED` — **[PR Review]**
- [ ] Breaking change: new event class (`{Name}V2`) on new queue (`{queue-prefix}-{Name}V2-{env}`) — **[PR Review]**
- [ ] During a breaking transition, both old and new event classes appear in the published spec; old one carries `@Schema(deprecated = true)` with a removal target date — **[PR Review]**
- [ ] Deprecation marker carries removal target date — **[PR Review]**

## Security

- [ ] Trust boundary stated in operation description — **[PR Review]**
- [ ] Producer and consumer service names documented per channel — **[PR Review]**
- [ ] Published `info.description` mentions KMS encryption-at-rest and links to the security runbook — **[PR Review]**

## Bump.sh / `info.description`

- [ ] NOT a copy of the README — **[PR Review]**
- [ ] Covers business surface / events published / events consumed / trust boundary / platform contract / versioning / canonical docs link — **[PR Review]**
- [ ] Events listed as bullets with one-phrase business meaning — **[PR Review]**
- [ ] No implementation-class mentions (`SqsTemplate`, `AbstractSQSStandardQueueMessageListener`) — **[PR Review]**
- [ ] No raw HTML, no emoji, no heading syntax inside descriptions — **[PR Review]**

## Consistency

- [ ] Same business concept worded identically across events (cross-check `docs/business/domain-glossary.md`) — **[PR Review]**
- [ ] New domain terms added to the Domain Glossary — **[PR Review]**
- [ ] Published `channels` map entries are sorted alphabetically by channel name (= SQS queue name, ASCII ascending) — **[PR Review]**
- [ ] Published `operations` map entries are sorted alphabetically by operation key (= operationId, `{Verb}{Noun}`, ASCII ascending) — **[PR Review]**

## Build & publication

- [ ] Published `asyncapi-v3.yaml` is machine-generated — no hand-edits — **[CI Gate]**
- [ ] `springwolf.enabled=true`, `springwolf.docket.base-package={base-package}.<service-name>`, and the full `springwolf.docket.info.*` + `springwolf.docket.servers.sqs-server.*` block set in `src/main/resources/application.properties` — **[CI Gate]**
- [ ] The same `springwolf.*` block ALSO set, with identical values, in `src/test/resources/application.properties` — the doc-generation test reads only the test classpath copy — **[CI Gate]**
