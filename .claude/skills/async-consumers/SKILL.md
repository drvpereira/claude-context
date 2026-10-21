---
name: async-consumers
description: SQS Standard Queue consumer implementation rules — idempotency, acknowledgement, error classification, DLQ setup and naming, visibility timeout, parallelism, message conversion, tracing, and AsyncAPI contract with SpringWolf. Use when implementing or reviewing any SQS listener or async message consumer.
---

# Async Consumers

Implementation rules for SQS Standard Queue consumers. These rules are non-negotiable — violations cause silent data loss, duplicate processing, or unrecoverable message failures.

---

## Idempotency — Mandatory

Every consumer must be idempotent. SQS Standard delivers at-least-once — duplicate messages are guaranteed to arrive.

- Deduplicate using a `deduplication_id` (e.g. `entityId:operationId`) persisted to DB with a unique constraint — only one consumer wins, the rest skip cleanly
- Check deduplication at the very start of the consumer method, before any processing begins
- Do not use application-level `if` checks alone — the unique constraint in DB is the guard

---

## Acknowledgement

- Acknowledge messages only after successful processing — use `ON_SUCCESS` mode (default)
- Never use `ALWAYS` unless explicitly justified in the spec — it discards messages on failure
- Never acknowledge before processing completes — a crash between ack and completion causes silent data loss

---

## Error Classification

Classify every error as retriable or non-retriable before throwing. Never decide retry behaviour inline.

| Error type | Strategy |
|---|---|
| `ConnectException`, `TimeoutException`, `SocketTimeoutException` | Retriable — rethrow, message returns to queue |
| DB connection failure | Retriable — rethrow |
| External service 5xx | Retriable — rethrow |
| External service 4xx | Non-retriable — log and skip, do not rethrow |
| Validation / `IllegalArgumentException` | Non-retriable — log and skip, do not rethrow |
| Deserialization failure (`JsonProcessingException`, etc.) | Non-retriable — message is permanently malformed; log with full payload context and skip; retrying will always fail |

- **Retriable**: rethrow as `RuntimeException` — message becomes visible again after visibility timeout; goes to DLQ after `maxReceiveCount` retries are exhausted
- **Non-retriable**: log with full context and skip — do not rethrow; message is acknowledged and permanently removed from the queue (retrying a non-retriable error produces the same failure)
- Use a classified `ErrorHandler` bean — never inline retry decisions inside the consumer method

---

## DLQ (SQS Standard Queue)

- Every queue must have a DLQ configured — `maxReceiveCount = 3` unless spec defines otherwise. Exception: if the spec explicitly documents why a DLQ is not needed for a given queue, it may be omitted.
- **Naming convention**: `{queue-prefix}-{QueueNameCamelCase}-{environment}-dlq` — e.g. `APP-OrderProcessing-prd-dlq`, `APP-PaymentEvents-stg-dlq`. Source queue follows the same pattern without the `-dlq` suffix: `{queue-prefix}-{QueueNameCamelCase}-{environment}`. `{queue-prefix}` is defined in `CLAUDE.md` → *Project Settings* (`APP` in these examples); never deviate within a project without justification in the spec.
- Set a CloudWatch alarm on `ApproximateNumberOfMessagesVisible` (`> 0` — any DLQ message is an alert condition) and `ApproximateAgeOfOldestMessage` (threshold defined in spec) on every DLQ
- Route CloudWatch alarms to an SNS topic that delivers email notifications — the accepted alert mechanism
- Inspect DLQ messages for recurring patterns: deserialization errors, validation failures, timeout spikes

---

## Visibility Timeout (SQS Standard Queue)

- Visibility timeout must always exceed the maximum processing time for a single message
- **Default: 30s — accepted for most consumers.** Override in the spec only when processing is expected to regularly exceed 30s; document the expected processing duration and the chosen timeout together

---

## Maximum Processing Time Guard

> **Team extension** — this pattern is not part of the accepted ADR decisions. Apply it only when the spec identifies unbounded or unpredictable processing times that risk visibility timeout expiry. Requires explicit justification in the spec before implementing.

Consumers may enforce a maximum processing duration per message. If the limit is exceeded, abort and rethrow so the message returns to the queue for retry.

A stuck consumer holds the visibility timeout open, blocks queue throughput, and eventually exhausts the thread pool silently.

```java
// Enforce a hard deadline per message
Future<Void> task = executor.submit(() -> processMessage(payload));
try {
    task.get(MAX_PROCESSING_SECONDS, TimeUnit.SECONDS);
} catch (TimeoutException e) {
    task.cancel(true);
    throw new RuntimeException("Processing exceeded time limit — message will be retried", e); // project-defined retriable exception type
}
```

- Define `MAX_PROCESSING_SECONDS` in configuration — never hardcoded
- The timeout must be shorter than the visibility timeout to guarantee the message becomes visible for retry before SQS re-delivers it
- Log a warning with `correlationId` and elapsed time before rethrowing

---

## Parallelism & Concurrency

- **Default: use Spring Boot SQS listener defaults.** Do not tune concurrency settings without explicit justification in the spec.
- Horizontal scaling is achieved by running multiple instances (pods/containers), each consuming from the same queue — this is the preferred scaling strategy
- If the spec identifies a consumer that requires tuned concurrency (high throughput, latency-sensitive), define the thread pool size and listener concurrency settings in the spec before implementation

---

## Message Conversion

- Remove the default `javaType` header from producer messages — it couples producer and consumer by FQCN and causes `ClassNotFoundException` when models diverge
- Producer and consumer must not share model classes — deserialise into a local DTO, never a shared library type

---

## Tracing & Correlation

- Include `correlationId` (or `traceId`) in every message header — propagate across service boundaries
- Use Micrometer Tracing or OpenTelemetry — infer from project
- Log `correlationId` on every consumer log line — never process a message without it in the MDC

---

## AsyncAPI Contract (SpringWolf)

- Annotate every `@SqsListener` handler with SpringWolf's `@AsyncListener` — declare the queue name and payload type
- The AsyncAPI spec is generated automatically from annotations — never maintain a separate YAML file alongside the code
- Regenerate the spec on every consumer change — never let annotations drift from the implementation
- Missing SpringWolf annotations on a consumer = Blocker, same as missing OpenAPI annotations on a REST endpoint

---

## Related Skills

- `idempotency` — idempotency key patterns and deduplication implementation for mutating operations
- `clean-architecture` — transaction-boundary placement, "no external I/O inside a DB transaction" rule, framework isolation
- `domain-driven-design` — domain event publication semantics (Transactional Outbox vs `@TransactionalEventListener AFTER_COMMIT`)
- `http-semantics` — status code semantics for synchronous endpoints that emit async events
- `spring-boot-patterns` — Spring service / configuration patterns referenced from consumer handlers
- `java-code-review` — general Java review checklist covering null safety, exception handling, and concurrency
