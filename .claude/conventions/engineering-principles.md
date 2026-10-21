# Engineering Principles

Non-negotiable standards for all work. Referenced from `CLAUDE.md`.

## API Contracts
Extend in place whenever possible. Create a new version only when an existing client would break.

**Breaking changes — new version required:**
- Field removed or renamed
- Type changed
- Status code or path changed
- Optional field made required

**Non-breaking — extend in place:**
- New field
- New optional parameter
- New endpoint
- New enum value

**Versioning convention:** run `/api/v2/` alongside `/api/v1/`. New versions default off via feature flag: `{feature-name}.api-v2.enabled=false` (e.g. `payments.api-v2.enabled=false`).

## Simplicity Over Perfection
Prefer simple, working solutions over design perfection. When an engineer identifies unnecessary complexity, they must flag it with a simpler alternative — not just raise the concern.

## Pagination
Mandatory from day one on every list endpoint. Never deferred.

## Idempotency
All mutating endpoints must be idempotent. Design this during planning — not as a retrofit.

## Blocker Overrides
When a blocker is overridden, it must be logged — never silent.

Log in spec under `## Risks & Mitigations`:
`[Agent] [date] OVERRIDDEN: [what] / [reason] / [risk]`

Commit prefix: `[OVERRIDE]`

## Spec as Source of Truth
The spec is the source of truth — not conversation history.

- After each phase: post a summary of decisions made in the conversation so the user can review and confirm
- If context degrades (responses become inconsistent, agents lose track of prior decisions, or cost thresholds are hit) → run `/compact` or start a fresh session with the spec loaded
- Session ending → read `.claude/skills/session-handover/SKILL.md` and produce the handover document

## Cost Awareness
After each of the following milestones — spec approved, implementation complete, peer review done, QA sign-off — post a context status update.

| Context Usage | Action |
|---|---|
| Above 50% | Suggest `/compact` |
| Above 70% | Require `/compact` before continuing |
