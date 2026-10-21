---
name: observability
description: Production observability — Micrometer metrics, structured logging, MDC correlation IDs, OpenTelemetry tracing, business metrics vs technical metrics, health checks. Use when instrumenting a new endpoint, adding metrics, configuring logs, or diagnosing why an incident took too long to detect.
---

# Observability

Three pillars: **metrics**, **logs**, **traces**. Each answers a different question:
- Metrics → *Is something wrong?* (cheap, aggregated)
- Logs → *What exactly happened?* (expensive, detailed)
- Traces → *Where in the request flow did it happen?* (correlation across services)

A system without all three is a system that can be down for hours before anyone notices.

## When to Use
- Adding metrics, logs, or tracing to a new endpoint or consumer
- Reviewing logging in a code review (PII leaks, log levels, structured fields)
- Defining alert thresholds in the spec
- Investigating why an outage was detected slowly
- Setting up dashboards for a new service

---

## Metrics — Micrometer

Spring Boot 3 includes Micrometer Observation by default. Wire it through the Actuator.

```yaml
management:
  endpoints.web.exposure.include: health, metrics, prometheus
  metrics:
    distribution.percentiles-histogram.http.server.requests: true
    tags.application: ${spring.application.name}
```

### Three Metric Types

| Type | When to use | Example |
|---|---|---|
| **Counter** | Monotonically increasing events | `orders_created_total`, `payments_failed_total` |
| **Gauge** | Point-in-time value that can go up or down | `cache_size`, `active_connections` |
| **Timer / Histogram** | Latency distributions | `http.server.requests` (auto-instrumented), `external_call_duration` |

### Required Metrics per New Endpoint

Every new endpoint must instrument:
1. **Latency histogram** — auto-instrumented via `http.server.requests` when Actuator is enabled
2. **Error rate counter** — track 4xx and 5xx separately; auto-instrumented with status code tag

### Business Metrics — The Important Ones

Technical metrics (latency, error rate, throughput) tell you *the system is healthy*. **Business metrics** tell you *the business is working*.

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final MeterRegistry meterRegistry;
    private final OrderRepository orderRepository;

    @Transactional
    public OrderDTO create(CreateOrderRequest request) {
        Order order = Order.create(request.customerId(), request.items());
        Order saved = orderRepository.save(order);

        meterRegistry.counter("orders.created",
            "tenant", request.tenantId(),
            "channel", request.channel()
        ).increment();

        return orderMapper.toResponse(saved);
    }
}
```

**Required business metrics per significant state transition:**
- Counter per outcome: `orders.created`, `orders.cancelled`, `payments.failed`, `seats.reserved`
- Tag with low-cardinality dimensions: tenant, channel, region, outcome
- Never tag with high-cardinality values (user ID, order ID, request ID) — these cause cardinality explosion

---

## Logging

### Structured Logging

Production logs must be structured (JSON), not human-prose. Use Logback's `LogstashEncoder` or `JsonLayout`.

```xml
<!-- logback-spring.xml -->
<configuration>
    <springProfile name="prod | staging">
        <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="net.logstash.logback.encoder.LogstashEncoder">
                <includeMdcKeyName>traceId</includeMdcKeyName>
                <includeMdcKeyName>spanId</includeMdcKeyName>
                <includeMdcKeyName>correlationId</includeMdcKeyName>
                <includeMdcKeyName>tenantId</includeMdcKeyName>
            </encoder>
        </appender>
        <root level="INFO"><appender-ref ref="JSON"/></root>
    </springProfile>

    <springProfile name="local | test">
        <appender name="HUMAN" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>%d %-5level [%thread] %logger{36} - %msg%n</pattern>
            </encoder>
        </appender>
        <root level="INFO"><appender-ref ref="HUMAN"/></root>
    </springProfile>
</configuration>
```

### Log Levels — What Each Means

| Level | Meaning | Examples |
|---|---|---|
| `ERROR` | Actionable failure that requires human attention | DB connection pool exhausted, unhandled exception, payment gateway down |
| `WARN` | Something is wrong but the system recovered | Cache miss, retry succeeded after first failure, deprecated API used |
| `INFO` | Notable business events | Order created, user logged in, batch job started/finished |
| `DEBUG` | Verbose diagnostic information | Method entry/exit, intermediate state, SQL queries |
| `TRACE` | Extremely fine-grained — almost never enabled in production | Per-iteration values inside a loop |

**Rules:**
- `ERROR` is reserved for actionable failures — never use it for expected outcomes (validation failures, 404s)
- Every `ERROR` log must include the operation, input shape (not values), and the exception with stack trace
- `WARN` indicates a degraded state — use it for retries, fallbacks, deprecated paths
- Default production level is `INFO`; turn on `DEBUG` only via runtime configuration (never default-on)

### Structured Fields, Not String Interpolation

```java
// ❌ BAD: String interpolation hides fields and risks logging sensitive values
log.info("Order " + order.getId() + " created for customer " + order.getCustomerEmail());

// ✅ GOOD: Structured fields — searchable, never leaks values that should not be logged
log.info("Order created",
    kv("orderId", order.getId()),
    kv("tenantId", order.getTenantId()),
    kv("channel", order.getChannel())
);
// Note: customer email is PII — not logged
```

(With Logback `kv` requires the `net.logstash.logback:logstash-logback-encoder` library.)

### PII — Never in Logs

- Never log credentials (passwords, tokens, API keys, session IDs)
- Never log PII (names, email addresses, phone numbers, national IDs, payment data)
- Log operation context, field names, and error shape — never field values for sensitive fields
- Body logging is forbidden by default — if a specific debug case requires it, mask sensitive fields and log only via a `DEBUG` level guarded by configuration

---

## MDC and Correlation

Every request must carry a `correlationId` (or `traceId`) end-to-end. Every log line on the request path must include it.

```java
@Component
public class CorrelationIdFilter extends OncePerRequestFilter {

    private static final String HEADER = "X-Correlation-Id";

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain chain) throws ServletException, IOException {

        String correlationId = Optional.ofNullable(request.getHeader(HEADER))
            .orElseGet(() -> UUID.randomUUID().toString());

        MDC.put("correlationId", correlationId);
        response.setHeader(HEADER, correlationId);
        try {
            chain.doFilter(request, response);
        } finally {
            MDC.remove("correlationId");
        }
    }
}
```

For async / messaging boundaries, propagate the correlation ID explicitly via message headers — Micrometer Tracing or OpenTelemetry can do this automatically when configured.

---

## Tracing — OpenTelemetry / Micrometer Tracing

Spring Boot 3 ships with **Micrometer Tracing** as the bridge to OpenTelemetry.

```yaml
management:
  tracing:
    sampling.probability: 1.0  # adjust per environment — 0.1 (10%) in prod is common
  otlp:
    tracing:
      endpoint: http://otel-collector:4318/v1/traces
```

**What to trace:**
- Every HTTP request entry (auto-instrumented)
- Every external HTTP call (auto-instrumented via `RestClient` / `WebClient`)
- Every async message produce/consume (instrumented via Micrometer Tracing's SQS/Kafka modules)
- Significant business operations — wrap in `Observation.createNotStarted(...)` to surface as spans

```java
@Service
@RequiredArgsConstructor
public class PaymentService {

    private final ObservationRegistry observationRegistry;

    public PaymentResult process(PaymentRequest request) {
        return Observation.createNotStarted("payment.process", observationRegistry)
            .lowCardinalityKeyValue("gateway", request.gateway())
            .observe(() -> doProcess(request));
    }
}
```

---

## Health Checks

Spring Boot Actuator provides `/actuator/health` out of the box. Wire health indicators for every critical dependency.

```yaml
management:
  endpoint.health:
    show-details: when-authorized
    probes.enabled: true       # /actuator/health/liveness and /readiness
  health:
    db.enabled: true
    redis.enabled: true
    diskspace.enabled: false   # rarely useful; high false-positive rate
```

**Liveness vs readiness** (Kubernetes-aware):
- **Liveness**: "should this pod be restarted?" — fail only on unrecoverable state (deadlock, OOM)
- **Readiness**: "should this pod receive traffic?" — fail when dependencies are down

Each external integration must have a corresponding `HealthIndicator` — the Architect's external-integrations spec requires this.

---

## Alerts vs Dashboards

- **Alerts** are for things a human must act on right now — paging-grade signals only. Configure a threshold + duration (e.g. error rate >1% for 5 minutes)
- **Dashboards** are for diagnosis and trend visibility — graphs of every relevant metric, queryable
- Every new endpoint must have at least one alert configured before going to production — define the threshold in the spec, link to the dashboard in the runbook

---

## Anti-Patterns

- **`log.info("...")` with no structured fields** — unsearchable in production
- **`ERROR` level on expected outcomes** (validation, 404) — alert fatigue, real errors get lost
- **PII in any log** — GDPR violation, audit failure
- **`catch (Exception e) { log.error("error", e); }`** silent-catch with no rethrow — error swallowed, request returns success
- **High-cardinality tags on metrics** (request ID, user ID, order ID) — explodes Prometheus storage, slow queries
- **No business metrics, only technical ones** — system is "green" while orders are silently failing
- **Sampling at 100% in production** — high cost; sample 1–10% with always-on sampling for errors and slow requests
- **Health check that calls every downstream service** — cascading failures; a downstream blip takes the pod out of rotation

---

## Related Skills

- `async-consumers` — consumer instrumentation, `correlationId` propagation across message boundaries
- `spring-boot-patterns` — Actuator endpoints, configuration patterns
- `clean-architecture` — observability is a cross-cutting concern; instrumentation lives in the Application or Infrastructure layer, never in Domain
- `security-audit` — review log output for PII; review actuator endpoint exposure
