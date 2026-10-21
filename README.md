# Claude Engineering Context

A reusable Claude Code engineering context: an orchestrator, specialised agents, skills and conventions for spec-first delivery.

Drop it into a workspace and Claude Code works as an **Engineering Orchestrator**. Before it writes any code it leads a team of specialised agents through a phased workflow: requirements, spec, tests, implementation, review and commit. The guiding principle is *measure twice, cut once*.

## Who it's for

The agents and skills target this stack:

- **Backend:** Java / Spring Boot, JPA/Hibernate, Flyway or Liquibase, SpringDoc (OpenAPI), SpringWolf (AsyncAPI), AWS SQS
- **Frontend:** React (web) and React Native (mobile), React Query, Zustand
- **Docs:** Markdown and Mermaid, with API references published from code annotations (e.g. Bump.sh)

The workflow, conventions and most paradigm skills (clean architecture, DDD, HTTP semantics, idempotency, caching, observability) are stack-agnostic. Use what fits and drop the rest.

## What's inside

| Path | Purpose |
|---|---|
| `CLAUDE.md` | Engineering Orchestrator: pre-action routing, workflow, principles and agent rules |
| `.claude/agents/` | Agent definitions: architect, security, product, QA, Java / React / React Native engineers, UX/UI, legal copywriter, documentation writer |
| `.claude/skills/` | 27 reusable skills (see below) |
| `.claude/conventions/` | Engineering principles, project conventions, architecture standards, definition of done, OpenAPI/AsyncAPI conventions and checklists, README rubrics |
| `.claude/workflow/` | Core workflow (phases 1–7), bug-fix workflow, agent communication protocol, agent invocation rules |
| `.claude/templates/` | ADR and spec templates |
| `.claude/settings.json` | Shared Claude Code settings and hooks |
| `setup.sh` | Links this context into a workspace and installs tooling |

## Quick start

**Requirements:** [Claude Code](https://docs.claude.com/en/docs/claude-code), Python 3.10+, and one of `uv`, `pipx` or Homebrew.

```bash
git clone https://github.com/drvpereira/claude-context.git
cd claude-context
./setup.sh ~/Projects/my-app
```

`setup.sh` does the following:

1. Symlinks `CLAUDE.md` and `.claude/` into the workspace, so every workspace shares one context and `git pull` here updates them all.
2. Installs [code-review-graph](https://github.com/tirth8205/code-review-graph) and registers it as an MCP server with Claude Code.
3. Creates `.code-review-graphignore` in the workspace with sensible exclusions.
4. Adds `.code-review-graph/` to the workspace `.gitignore`.
5. Builds the initial code graph for the workspace.

> **Note:** `setup.sh` never overwrites existing files. If the workspace already has its own `CLAUDE.md` or `.claude/`, it stops and asks you to move them aside first. Re-running it on an already-linked workspace is safe.

Then open Claude Code in the workspace and describe a feature or a bug. The orchestrator starts at Phase 1.

## Customise for your organisation

Edit these once, in your clone of this repo. Every linked workspace picks them up.

### 1. Project Settings (`CLAUDE.md`)

The API and messaging conventions use named placeholders. Each one is defined once in the **Project Settings** table in `CLAUDE.md`:

| Placeholder | What to set | Example | Used in |
|---|---|---|---|
| `{team-name}` | API contact name in every published spec | `Platform Team` | OpenAPI conventions |
| `{team-email}` | API contact email in every published spec | `platform-team@example.com` | OpenAPI and AsyncAPI conventions and checklists |
| `{api-url-stg}` | Default server URL, `stg` | `https://api.stg.example.com` | OpenAPI conventions |
| `{api-url-prd}` | Default server URL, `prd` | `https://api.example.com` | OpenAPI conventions |
| `{base-package}` | Root Java package (`{base-package}.<service-name>`) | `com.example` | SpringDoc `packages-to-scan`, SpringWolf `base-package` |
| `{commons-library}` | Shared library with reusable schemas and infrastructure | `example-commons` | OpenAPI conventions |
| `{queue-prefix}` | SQS queue and DLQ name prefix | `APP` | AsyncAPI conventions, `async-consumers` |
| `{aws-region}` | Default AWS region for SQS | `eu-west-1` | AsyncAPI conventions |

Replace each `_not set_` in the **Value** column. Until a value is set, Claude asks you for it rather than guessing, and `setup.sh` prints a reminder listing what's missing. `setup.sh` never edits these files, so `git pull` stays conflict-free apart from that one table.

### 2. Repository settings (`CLAUDE.md` → Fast-Path Rules)

| Setting | Default |
|---|---|
| Base branch (branch new work from) | `main` |
| PR target (merge work into) | `main`, or set to `develop` if you use an integration branch |

Branch naming is `feature/` or `hotfix/`, with an optional `TICKET-ID` prefix.

### 3. Issue tracker (per workspace, optional)

The `bug-ticket` and `story-ticket` skills read an optional `docs/issue-tracker.md` in the workspace: which tracker you use, parent/epic tickets per ticket type, and application/component codes for ticket summaries. Without it, the skills ask.

### What you don't need to change

These are **illustrative only**: the Orders/Customers domain in the examples, `ROLE_CUSTOMER`, `OrderController`, `CustomerRegisteredEvent`, queue names like `APP-OrderProcessing-prd`, and `com.example` / `example.com` inside code samples in the skills.

### Tunable defaults

These are opinionated defaults. Change them in the conventions if they don't fit:
- 90%+ unit coverage on new and changed code (`definition-of-done.md`)
- Page size 50, with a maximum of 100, and p99 under 500 ms (`architecture-standards.md`)
- `stg` / `prd` environment names (OpenAPI conventions)
- Optimistic locking by default (`architecture-standards.md`)

## Workflow at a glance

1. **Requirements:** gap analysis, kill vague language, surface risks, lock test scope.
2. **Spec:** written to `docs/specs/YYYY.MM.DD-feature/` and signed off by all in-scope agents.
3. **Design review:** architecture, data model, security, UX.
4. **Tests first:** QA owns the tests, which fail for the right reasons.
5. **Implementation:** strictly per spec, with a reviewer agent checking line by line.
6. **README update.**
7. **Commit:** atomic and spec-referenced. Pushing always requires explicit approval.

Bugs follow the same phases, starting with a reproducing test (`.claude/workflow/bug-fix-workflow.md`).

## Agents

| Agent | Responsibility |
|---|---|
| Lead Architect | Technical design, data modelling, architecture |
| Senior Java Engineer | Spring Boot backend implementation |
| Senior React Engineer | Web frontend implementation |
| Senior React Native Engineer | Mobile implementation |
| Senior QA Engineer | Test strategy, test ownership |
| Security Expert | Security review, OWASP compliance |
| Product Expert | Product direction, scope, user value |
| UX/UI Designer | User flows, UI consistency |
| Legal Copywriter | User-facing copy, consent flows, i18n |
| Documentation Writer | Canonical docs under `/docs/`: business, technical, security, ADRs, diagrams |

## Skills

**Workflow & process:** `planning` (phases 1–2 orchestration and spec production) and `session-handover` (end-of-session handover document).

**Architecture paradigms:** `clean-architecture` (layering, dependency direction, transaction boundaries) and `domain-driven-design` (aggregates, domain events, value objects, ubiquitous language).

**Java & Spring Boot:** `java-code-review`, `spring-boot-patterns`, `security-audit` (OWASP Top 10) and `test-quality` (JUnit 5 + AssertJ).

**JPA / persistence:** `jpa-patterns` (index), `jpa-fetching`, `jpa-transactions`, `jpa-relationships`, `jpa-queries`, `jpa-locking` and `database-migrations`.

**Operations & security:** `spring-security`, `caching-strategies` and `observability`.

**REST & async:** `http-semantics`, `idempotency`, `async-consumers` (SQS consumer rules) and `api-docs-rules` (deciding whether a change is documentation-only for REST and AsyncAPI).

**Frontend:** `frontend-conventions` (React and React Native) and `accessibility` (web and mobile profiles).

**Tooling & tickets:** `mermaid-diagrams` (local diagrams with `mmdc`), `bug-ticket` and `story-ticket` (tracker-neutral ticket drafts).

## Settings and hooks

`.claude/settings.json` ships with:

- **`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`** enables Claude Code's experimental agent-teams feature, which the orchestrator uses. Remove it to opt out.
- **Stop / Notification hooks** play a sound on macOS (`afplay`). They do nothing on other platforms.
- **PostToolUse / SessionStart hooks** keep the code-review-graph index up to date in git repositories.

## code-review-graph

[code-review-graph](https://github.com/tirth8205/code-review-graph) (MIT, © Tirth Kanani) is a local MCP server that builds a structural map of your codebase. Claude uses it to focus reviews on the files a change affects, which uses far fewer tokens.

- It runs locally. No cloud dependency, and no data leaves your machine.
- Small edits are picked up automatically via hooks. After large restructurings, run `code-review-graph update` in the workspace.
- Commit `.code-review-graphignore`, but never `.code-review-graph/` (a local SQLite index).

To run without it, skip `setup.sh` steps 2–5, remove the graph hooks from `.claude/settings.json`, and delete the *MCP Tools: code-review-graph* section from `CLAUDE.md`.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE) © 2026 David Pereira
