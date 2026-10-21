---
name: session-handover
description: Produces a self-contained handover document when a session is ending, context limit is approaching, or work must continue in a new session. Use when the user says "let's wrap up", "handover", "start a new session", or context is getting long.
---

# Session Handover

Use when the current session is ending, context limit is approaching, or the user wants to continue work in a new session. Produces a self-contained handover document that a new session can load instead of reading conversation history.

**Trigger phrases**: "let's wrap up", "context is getting long", "start a new session", "handover", "summarise where we are"

---

## How to Produce the Handover

Read the current spec (`docs/specs/YYYY.MM.DD-feature-name/YYYY.MM.DD-feature-name.md`) and the messages since the last spec update in this session (or the last 10–15 messages if no spec update occurred). Do not attempt to re-read the entire conversation — rely on the spec as the source of truth and only use recent messages to capture what is not yet in the spec.

If no spec exists yet (handover triggered mid-planning, before the Final Feature Spec is produced): document the decisions made so far in each gate, the open questions remaining, and the exact gate where work stopped. The new session must resume from that gate, not restart from Requirement Gap Analysis.

Save to: `docs/handover/YYYY.MM.DD-HHmm-[feature-name].md`

---

## Handover Template

```markdown
# Session Handover — [Feature Name]
Date: [date and time]
Spec: [relative path to YYYY.MM.DD-feature-name.md]

## Current Status
Workflow step: [Phase 1: Requirement Gathering & Brainstorming / Phase 2: Spec Definition / Phase 3: Spec Delivery / Phase 4: Test Implementation / Phase 5: Business Logic Implementation / Phase 6: README Update / Phase 7: Commit / Done]
Overall progress: [one sentence — what is complete, what remains]

## Git State
Branch: [branch name, e.g. feature/PROJ-1234-order-expiry]
Committed: [yes / partial — list uncommitted files]
Staged: [list staged files, or "none"]
Unstaged: [list unstaged files, or "none"]

## What Was Implemented
List files created or modified — one line each:
- `path/to/file.java` — [what it does]
- `path/to/file.ts` — [what it does]

## What Was Tested
- Unit tests: [passing / failing / not yet written]
- Integration tests: [passing / failing / not yet written]
- E2E tests: [passing / failing / not yet written]
- Known failing tests: [list with reason]

## Decisions Made (Do Not Re-debate)
These were explicitly agreed by agents — do not reopen unless new information changes the situation:
- [Decision]: [one sentence on what was decided and why]
- [Decision]: [one sentence on what was decided and why]

## What Was Explicitly Rejected and Why
These were considered and ruled out — saves the new session from re-proposing the same ideas:
- [Rejected option]: [why it was rejected]

## Open Questions
Items not yet resolved — new session should address these first:
| # | Question | Owner | Priority |
|---|----------|-------|----------|
| 1 | ...      | ...   | High/Med/Low |

## Immediate Next Step
**The single next action the new session must take** — one sentence, unambiguous:
[e.g. "Implement the `/api/v1/commits` endpoint per spec section 6, starting with the service layer."]

## How to Start the New Session
Ask the user to open a new session and paste:
> "Continue work on [feature name]. Load the spec at [spec path] and the handover at [handover path]. The relevant skills for this work are: [list applicable skill names from CLAUDE.md Skills table, e.g. `async-consumers`, `http-semantics`]. Start from the immediate next step."
```

---

## Rules
- Never summarise decisions from memory — read the spec and verify
- If a decision is not in the spec, it does not belong in "Decisions Made" — flag it as an open question instead
- The "Immediate Next Step" must be specific enough that the new session can start without asking any clarifying questions
- Keep the entire document under 120 lines — if it is longer, you are including too much detail

---

## Related Skills

- `planning` — the spec is the source of truth; handover loads from it and the recent messages, not from full conversation history
