# Agent Invocation Rules

Routing logic for which agents run when. Referenced from `CLAUDE.md`.

## Planning
Full team, always. The only exception is a user-explicitly reduced team — treat it as a deliberate override, not a shortcut.

## Implementation & Review — Smart Routing

**By tech stack:**
- Java → backend agent
- React → web frontend agent
- React Native → mobile agent (not the web frontend agent)

**Always invoked:**
- QA — every phase
- Architect — spec review and code peer review, every phase

**Conditionally invoked:**
- **Security** — invoke for: auth, PII, external integrations, trust boundaries, compliance, public APIs. Skip for: pure internal logic with no external surface (e.g. a private utility method with no I/O or data persistence).
- **Product Expert** — invoke for: requirements validation, business value assessment, scope decisions, and any change with user-facing impact. Skip for: pure technical refactoring with no product or UX surface.
- **UX/UI Designer** — invoke per involvement classification defined in `.claude/agents/ux-ui-designer.md`.
- **Legal Copywriter** — invoke for: any feature with user-facing copy, consent flows, new translation keys, or legal document impact. Skip for: backend-only changes with no UI or legal surface.
- **Documentation Writer** — invoke whenever documentation needs to be written or updated, including: business documentation (capability map, domain glossary, customer journeys, stakeholder summaries, business-process write-ups), technical documentation (architecture maps, technical specs, data persistence schemas, gaps and ADRs), security & permissions documentation, flow / sequence / ER diagrams (Mermaid), OpenAPI / `@Schema` annotations, README sections, release notes, and anything under `/docs/` (`/docs/business/`, `/docs/technical/`, `/docs/security/`, `/docs/guides/`, `/docs/specs/`, `/docs/decisions/`, `/docs/handover/`). Also invoke for any change that touches a business surface (capability, domain term, user-facing flow), API contract, data model, domain event, or security surface. **Business documentation is first-class** — invoke for capability changes and domain-vocabulary changes even when no technical surface is affected. Skip for: backend-only changes with no business or external surface (API reference docs are generated from code annotations).

## Ambiguous Routing
When a feature spans multiple domains (e.g. Java + React + consent flow), invoke all relevant agents. The Architect leads coordination.

## Overrides
User-defined agent selections override all defaults. Treat them as explicit direction, not an exception.
