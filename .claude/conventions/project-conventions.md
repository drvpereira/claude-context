# Project Conventions

File layout, naming, i18n, git. Referenced from `CLAUDE.md`.

## File & Directory Structure

| Artifact | Path |
|---|---|
| Spec | `docs/specs/YYYY.MM.DD-feature-name/YYYY.MM.DD-feature-name.md` |
| Spec diagrams | Same spec directory — `.mmd` source + `.png` output |
| Handovers | `docs/handover/YYYY.MM.DD-HHmm-feature-name.md` |
| Scratchpad | `SCRATCHPAD.md` at root — delete after spec is written and agreed |
| ADRs | `docs/architecture/decisions/adr-NNNN-short-title.md` |
| Canonical business docs (cross-cutting) | `docs/business/capability-map.md`, `docs/business/domain-glossary.md`, `docs/business/customer-journeys/customer-journeys.md` |
| Canonical business docs (per-domain) | `docs/business/<domain>/{stakeholder-summary,business-process}.md` |
| Canonical technical docs (per-domain) | `docs/architecture/domains/<domain>/{architecture-map,technical-spec,data-persistence,gaps-and-adrs}.md` |
| Canonical security docs (per-domain) | `docs/architecture/security/<domain>.md` |
| Canonical doc diagrams | Per domain — `docs/<audience>/<domain>/diagrams/` (`.mmd` source + `.png` output) |
| Engineer guides | `docs/guides/` |
| Ticket drafts | `docs/tickets/` |

See `.claude/agents/documentation-writer.md` for the full folder structure and ownership rules.

## `.claudeignore`
Exclude the following from Claude's context:

- `node_modules/`
- `build/`, `dist/`
- `.gradle/`, `target/`
- `__pycache__/`, `.venv/`
- `*.log`
- Large fixture files

## Test Naming
Test descriptions must use business language — what the user sees, can do, or cannot do.

**Good:** `"user cannot submit the form without a valid email"`
**Bad:** `"button has 12px padding and 94% opacity"`

Tests must survive a layout refactor without name or assertion changes, unless the underlying business requirement itself changed.

## Internationalisation (i18n)
- All user-facing text must be internationalised — no hardcoded copy
- Backend enums exposed to the UI must use translation keys
- No `dangerouslySetInnerHTML`
- Legal Copywriter owns copy content and translation consistency — engineers own mechanics only
- Copy disputes between Legal Copywriter and engineers escalate to the user

## Enums
- Format: `SCREAMING_SNAKE_CASE`
- Always use string name — never ordinal
- Every new enum exposed to the UI requires keys added to all language files

## Run Commands
- Single-command script per service
- POSIX-compatible
- `.env.example` must include all required keys — no undocumented environment variables

## Git
- Branch naming: `feature/`, or `hotfix/` followed by ticket ID (if available) and `short-description` — consistent with the Commit and Bug Fix Workflow sections
- Pre-commit hook order: linter → formatter → tests
- Never push to remote unless explicitly asked by the user
