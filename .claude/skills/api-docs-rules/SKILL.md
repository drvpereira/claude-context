# API Documentation Review — Operating Rules

You are working on API documentation. These rules exist because a prior
session converted a 50-finding review into 190 unilateral file edits, several
of which were behaviour-breaking and several of which were fabricated. Follow
these rules without exception.

The rules cover **both REST (Springdoc / Swagger) and AsyncAPI (SpringWolf)**
documentation. The documentation-vs-behaviour separation applies identically
to both.

## 1. Documentation vs behaviour — hard separation

### Documentation annotations

A **documentation** change may add, remove, or edit any parameter of the
annotations listed below — and only these. The same rule applies whether
you are adding a missing annotation, deleting a redundant one, or
adjusting a parameter value.

Several Springdoc annotations share names with Spring MVC annotations.
Always verify the imported package before classifying a change as documentation-only.

Example:

- Swagger `@io.swagger.v3.oas.annotations.parameters.RequestBody` = documentation
- Spring `@org.springframework.web.bind.annotation.RequestBody` = behaviour

**REST (Springdoc / Swagger):**
- `@Operation`
- `@Schema` (on classes, fields, or method parameters)
- `@ApiResponse`
- `@ExampleObject`
- `@Content`
- `@ArraySchema`
- `@Tag`
- `@Parameter`
- `@ParameterObject`
- `io.swagger.v3.oas.annotations.parameters.RequestBody` (not to be confused with Spring's `@RequestBody` — this one is documentation)
- `@Header`
- `@Headers`
- `@ExternalDocumentation`
- `@Callback`
- `@Link`
- `@DiscriminatorMapping`
- `@SecurityRequirement`
- `@SecurityScheme`
- `@OpenAPIDefinition`
- `@Server`, `@Contact`, `@Info`, `@License`
- `@Hidden` (Swagger-only — removes a field from the OpenAPI spec; **does not** affect JSON serialisation; this is *not* `@JsonIgnore`)

**AsyncAPI (SpringWolf):**
- `@AsyncPublisher` — documents that a method publishes
- `@AsyncListener` — documents that a method consumes
- `@AsyncOperation` (the inner value: `channelName`, `description`, `payloadType`, `message`, `headers`)
- `@AsyncOperation.Headers`, `@AsyncOperation.Headers.Header`
- `@AsyncMessage`
- `@AsyncApiPayload`
- Channel-binding annotations under
  `io.github.springwolf.bindings.*.annotations.*` (e.g.
  `@SqsAsyncOperationBinding`, `@KafkaAsyncOperationBinding`,
  `@AmqpAsyncOperationBinding`, `@JmsAsyncOperationBinding`)

**Documentation-only configuration/customisation:**

- `OpenApiCustomizer`
- `OperationCustomizer`
- `PropertyCustomizer`
- `OpenAPI` bean definitions that only affect generated specification metadata
-  `SpringWolf` configuration or metadata beans that only affect generated `AsyncAPI` metadata

Only when the change affects generated documentation metadata and does not alter runtime request handling, validation, serialization, security, routing, broker connectivity, listener registration, queue/topic provisioning, retry behaviour, or consumer execution semantics.

**Supporting:**
- Import statements that exist solely to support the annotations above

Adjustments that count as documentation: adding a missing `@Schema`, dropping a redundant per-method `@Parameter(name = "Authorization", …)` once a class-level `@SecurityRequirement` is in place, switching `requiredMode = REQUIRED` ↔ `NOT_REQUIRED`, adding a missing `@ApiResponse(responseCode = "404", …)`, adding `@AsyncPublisher` to a SpringWolf-discovered publisher method.

### Behaviour markers

A **behaviour** change is *any* modification — including adding,
removing, or editing the parameters of — anything else. In particular:

**Wire format / serialisation:**
- `@JsonFormat`, `@JsonIgnore`, `@JsonInclude`, `@JsonProperty`,
  `@JsonAlias`, `@JsonSubTypes`, `@JsonTypeInfo`
- Lombok annotations that affect serialisation or `toString()` output:
  `@Data`, `@Builder`, `@ToString`, `@ToString.Exclude`,
  `@EqualsAndHashCode` (when it changes equality contract)
- Adding, removing, or renaming fields on a request, response, entity, or event-payload record

**REST routing:**
- Path segments or verb in `@GetMapping` / `@PostMapping` /
  `@PutMapping` / `@DeleteMapping` / `@PatchMapping` / `@RequestMapping`
- `@PathVariable` ↔ `@RequestParam` swaps, or changing their `name`
- Method return types, request body types, path-variable types
- Spring `@org.springframework.web.bind.annotation.RequestBody`

**Messaging / async wiring:**
- `@SqsListener` (awspring) — defines an actual SQS subscription
- `@KafkaListener`, `@RabbitListener`, `@JmsListener`, `@StreamListener` — same reasoning for their respective brokers
- `@EventListener`, `@TransactionalEventListener` — Spring application events
- `SqsTemplate.send(...)`, `KafkaTemplate.send(...)`,
  `JmsTemplate.convertAndSend(...)`, `RabbitTemplate.convertAndSend(...)` or any other broker-template call inside a method body — these determine the actual queue/topic written to and the payload format
- Changing the channel-name expression in `@AsyncOperation(channelName)` if the matching `@SqsListener(value)` reads from the same property — documentation and behaviour must agree, but the change is governed by the behaviour side: align the doc *to* the behaviour, never the other way round

**Authentication and authorisation:**
- `@Secured`, `@PreAuthorize`, `@PostAuthorize`, `@RolesAllowed`, `@CheckXxx` annotations

**Input validation:**
- `@Valid`, `@NotNull`, `@NotBlank`, `@Size`, `@Pattern`, `@Email`, `@Min`, `@Max`, `@DecimalMin`, `@DecimalMax`, `@Past`, `@Future` — these *enforce* a constraint, they do not document it

**Method bodies and side effects:**
- HTTP status codes returned (`HttpStatus.X`, `ResponseEntity.status(...)`)
- `throw new ...` statements, exception types thrown
- `ResponseStatus` annotation on exceptions

**Spring lifecycle and wiring:**
- `@ConditionalOnProperty`, `@Profile`, `@Transactional`, `@Cacheable`, `@Async`, `@Scheduled`, `@Bean`, `@Component`, `@Service`, `@Repository`, `@Configuration`

**Structure:**
- Field declarations, method declarations, class structure
- Imports for non-documentation packages

### Bundling rule

**Never bundle a behaviour change into a documentation task.** If a review finding requires a behaviour change to be correct (for example "documented `404` is unreachable because the service returns `200 OK` with an `Either.left(error)` body", or "Lombok `@ToString` exposes PII in logs"), the choices are:

1. Adjust the *documentation* to match current behaviour, OR
2. Surface the finding and stop — the behaviour fix is a separate ticket with its own review.

You do not pick option 2 silently or fix the code yourself.

## 2. No fabrication

If you do not know something, do **not** invent it. Specifically banned:

- "use a reasonable existing role"
- "see XXXX" when XXXX is not a real ticket
- "future v2 contracts will…"
- "will be added in future versions"
- "forward-looking placeholder"
- "this is planned under…"
- Any identifier example you have not verified against a real model, test fixture, migration, or production sample
- Any role name you have not seen used elsewhere in the codebase
- Any "strategic owner is service X" claim not in the README or an ADR
- Any queue name, topic name, enum value, or broker channel you have not verified from code, tests, config, migrations, fixtures, or production samples

Examples, enum values, ids, queue names, topic names, and role names must come from:

- code,
- tests,
- fixtures,
- migrations,
- production samples,
- or explicit user confirmation.

If you do not have a citation, stop and ask the user.

## 3. Cite or ask — for every domain fact

Any claim about how the system works must come with one of:

- A source file + line number
- A test that demonstrates it
- A README, ADR, or migration that asserts it

If no citation, mark the claim `(needs user confirmation)` in your output and stop until the user resolves it.

Inference from framework conventions alone is insufficient evidence. Observed configuration or tests are required.

Examples of forbidden inference:

- "Spring will return 400 here"
- "Kafka retries three times by default"
- "this exception becomes a 404 automatically"

## 4. No forward-looking statements in published docs

Documentation describes the present. If a deprecation is real, the source has `@Deprecated`. If a roadmap item is real, the user named the ticket. Otherwise the doc must not promise future behaviour.

## 5. Review = present, not act

When review agents produce findings, **consolidate and present them**. Do not author fixes until the user has triaged the list and named specific findings to act on. A long findings list is a queue for triage, not a punch list for execution.

## 6. Generated artifacts are not source

Generated OpenAPI or AsyncAPI JSON/YAML artifacts must never be edited manually unless the repository explicitly treats them as source files.

Regenerate generated specifications from annotations or approved config instead of patching the generated output directly.

## 7. Pre-commit risk grep — mandatory

Before requesting permission to commit, run:

```bash
git diff -- '*.java' '*.kt' | grep -nE \
  "@JsonFormat|@JsonIgnore|@JsonInclude|@JsonProperty|@JsonAlias|@JsonSubTypes|@JsonTypeInfo|@(Get|Post|Put|Patch|Delete|Request)Mapping\(|@PathVariable|@RequestParam|@Secured\(|@PreAuthorize\(|@PostAuthorize\(|@RolesAllowed|HttpStatus\.|throw new |@ResponseStatus|@ConditionalOnProperty|@Profile|@Transactional|@Cacheable|@Async|@Scheduled|@Valid|@NotNull|@NotBlank|@Size\(|@Pattern\(|@Email|@Min\(|@Max\(|@SqsListener|@KafkaListener|@RabbitListener|@JmsListener|@StreamListener|@EventListener|@TransactionalEventListener|SqsTemplate\.|KafkaTemplate\.|JmsTemplate\.|RabbitTemplate\.|@ToString\.Exclude|@Data|@Builder"
```

If the output is non-empty, paste it to the user verbatim and stop. The user must sign off on each line before you commit.

## 8. Cap agent batches at 15 files

No subagent task may edit more than 15 files. After each batch, surface the diff (or `git diff --stat`) to the user before launching the next.

## 9. Show agent prompts before launch

Before launching any subagent that will edit files, paste the exact prompt back to the user and ask `Launch this prompt? [y/n]`. Subagents amplify your blind spots — prompts that license fabrication ("use a reasonable existing role") are the single biggest defect source.

## 10. After the first defect — stop and inventory

When the user identifies a single defect, **stop the work**. Do not surgically revert that one defect and continue. Instead, run an inventory of every change in the working tree of the same category, present it to the user, and wait for direction.

## 11. Do not assume cross-session memory

Do not assume conversational memory across sessions. Only rely on:

- the current session,
- repository files,
- or explicitly persisted project instructions (e.g. CLAUDE.md).

If the user references prior instructions not present in the current context or repository, ask for them again.

## 12. Document observable behaviour only

Do not add documented HTTP responses, AsyncAPI error semantics, retry behaviour, dead-letter behaviour, or security behaviour unless the mapping is observable through:

- controller code,
- exception handlers,
- integration tests,
- generated contracts,
- broker configuration,
- or existing published documentation.

Do not infer externally visible behaviour solely from internal
exceptions or framework conventions.

## 13. When in doubt, ask

If a rule above is ambiguous in a specific case, ask the user. The cost of one extra clarifying question is always lower than the cost of one defect that survives review.
