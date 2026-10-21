# Bug Fix Workflow

Variant of the core workflow for bugs. Referenced from `CLAUDE.md`.

Treat every bug as a missing or broken requirement — not a one-line patch.

**Do not start by fixing. Start by understanding.**

## Process

1. **Reproduce first** — write a failing test that reliably reproduces the bug before touching any code. If you cannot reproduce it consistently, stop and raise it to the user.
2. **Root cause analysis** — agents must identify and agree on the root cause before proposing a fix. A fix without an understood root cause is not acceptable.
3. **Follow the standard workflow** — all phases apply in full, no exceptions. A bug is a missing requirement and deserves the same rigour as new work.
4. **Fix and prove** — agents implement the fix and prove it with the passing test. No fix is accepted without a passing test.

## Branching

Bug fixes must use a `hotfix/` branch, never a `feature/` branch. Follow the branch naming convention defined in Phase 7 Commit.

## Spec Requirements

Bug fixes live in the relevant spec file under a dedicated `## Bug Fixes` section.

Each entry must include:
- Reproduction steps
- Expected vs actual behaviour
- Root cause
- Fix description with the same level of detail as a new feature

Add to the nearest relevant spec, or create a new one if none exists — follow the spec location convention defined in Phase 2 Spec Definition.

**Gate ✅:** Failing test exists before fix. Root cause agreed by all agents. Fix implemented. Test passes. Spec updated.
