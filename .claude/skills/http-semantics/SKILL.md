---
name: http-semantics
description: HTTP method contracts and status code usage for REST APIs. Use when implementing or reviewing endpoints — method contracts (GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS), status codes (including 202, 429, 503), Location header, DELETE idempotency, and RFC 9457 Problem Details error format.
---

# HTTP Semantics

## When to Use
- Defining REST endpoints in a spec — choosing methods and status codes
- Reviewing controller methods for correct HTTP semantics
- Choosing between `400`, `404`, `409`, `422` for a given error case
- Implementing or reviewing async-accepted endpoints (`202`) or rate-limit responses (`429`)
- Designing error response bodies (RFC 9457 ProblemDetail)

---

## Method Contracts

Never violate these — they are part of the HTTP contract, not a style choice.

| Method | Contract |
|---|---|
| `GET` | Side-effect free, safe to call multiple times, never modifies state |
| `HEAD` | Identical to `GET` but no response body — must return the same headers; handled by framework, not manually implemented |
| `POST` | Creates a new resource or triggers an operation; not idempotent by nature |
| `PUT` | Full replacement of a resource; must be idempotent |
| `PATCH` | Partial update only; must not replace the full resource. Not required to be idempotent by HTTP spec — if the spec requires idempotency, design it explicitly |
| `DELETE` | Removes a resource; must be idempotent (second call returns `404` or `204`, never `500`) |
| `OPTIONS` | CORS preflight — handled by the framework; never implement manually |

---

## Status Codes

Use the correct code every time — wrong codes mislead clients and break retry logic.

| Code | Meaning | When to use |
|---|---|---|
| `200 OK` | Success with response body | GET, PUT, PATCH returning updated resource |
| `201 Created` | Resource created | POST that creates a resource — include `Location` header |
| `202 Accepted` | Request accepted, processing not yet complete | Async operations — response must include enough context for the client to poll or track progress |
| `204 No Content` | Success with no body | DELETE, or PUT/PATCH when response body is not needed |
| `400 Bad Request` | Malformed request syntax | Unparseable JSON, missing required field at protocol level |
| `401 Unauthorized` | Not authenticated | No credentials supplied or credentials are invalid — client must authenticate |
| `403 Forbidden` | Authenticated but not authorised | Caller is known but does not have permission |
| `404 Not Found` | Resource does not exist | ID not found — for security-sensitive endpoints, define whether to reveal or hide existence in the spec |
| `409 Conflict` | State conflict | Duplicate creation, version mismatch when client should resolve |
| `422 Unprocessable Entity` | Valid syntax, business rule violation | Validation errors, invalid state transitions |
| `429 Too Many Requests` | Rate limit exceeded | Include `Retry-After` header when the retry window is known |
| `500 Internal Server Error` | Unexpected server failure | Always generic to client — full detail in logs only |
| `503 Service Unavailable` | Service temporarily unavailable | Dependency down, circuit open, or overload — include `Retry-After` when a recovery window is known; never use `500` for unavailability |

---

## Error Response Format

All error responses must follow **RFC 9457 Problem Details** (`application/problem+json`):

```json
{
  "type": "about:blank",
  "title": "Resource Not Found",
  "status": 404,
  "detail": "User not found with id: 42",
  "instance": "/api/v1/users/42"
}
```

- `type` — URI identifying the problem type; defaults to `about:blank` when not set
- `title` — short, stable human-readable summary; does not change per occurrence
- `status` — HTTP status code (mirrors the response status)
- `detail` — human-readable explanation specific to this occurrence
- `instance` — URI of the request that triggered the error

Extension members are permitted. Validation errors extend with `errors: [{ field, message }]`.

Never invent a custom error envelope (`{ code, message }`, `{ error }`, `{ errors }` at top level) — use Problem Details and extend it when additional fields are needed.

---

## Rules

- Never return `200` with an error body — use the correct error status code
- Always include a `Location` header on `201 Created` — value is the URI of the created resource
- For auth failures on sensitive resources, define your security posture in the spec and apply it consistently: use `403` to reveal that the resource exists (caller is authenticated but not authorised), or use `404` to hide existence entirely (when callers must not discover whether the resource is there). Never mix both for the same resource type
- `422` is for business rule violations; `400` is for malformed requests — do not conflate them
- `DELETE` must be idempotent — second call returns `404` or `204`, never `500`
- `429` must include a `Retry-After` header when the retry window is known — omitting it forces clients to guess
- Error responses must use `Content-Type: application/problem+json` — not `application/json`

---

## Related Skills

- `idempotency` — DELETE idempotency rules; `Idempotency-Key` header conventions for POST/PUT/PATCH
- `spring-boot-patterns` — `@RestControllerAdvice` for RFC 9457 ProblemDetail error responses
- `spring-security` — `401 Unauthorized` vs `403 Forbidden` distinction
- `async-consumers` — `202 Accepted` semantics for endpoints that publish events
