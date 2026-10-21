---
name: bug-ticket
description: Draft a complete, tracker-neutral bug ticket. Use when the user reports a bug, asks to log/create a bug ticket, or says 'write up this bug'. Gathers reproduction steps, expected vs actual behaviour, environment, affected applications, and produces ticket-ready Description content.
---

# Bug Ticket Skill

Use when the user wants to create a bug ticket in the project's issue tracker.

**Trigger phrases**: "create a bug ticket", "log a bug", "write up this bug", "bug ticket"

---

## Tracker Configuration

This skill is tracker-neutral (Jira, GitHub Issues, GitLab, Linear, …). Before gathering fields, look for an optional `docs/issue-tracker.md` in the workspace. If it exists, use it for:

- The tracker in use and how tickets are filed (paste a draft, CLI, or MCP tool)
- The parent / epic ticket(s) to attach to, by ticket type
- The list of applications or components and their short codes (used in the Summary)

If it does not exist, ask the user for anything you need and leave the parent blank rather than guessing.

---

## Information Gathering

Before drafting the ticket, collect all required fields. Ask only for what the user has not already provided. If anything is unclear, ask — do not assume. If the user asks to skip something, skip it.

### Required fields

| Field | Question to ask if missing |
|---|---|
| **Title** | "Give me a short title — what is broken?" |
| **Affected applications & who is affected** | "Which applications or components are impacted — one or more? And within those, is it all users or a specific role or condition (e.g. admins only, users with an expired subscription)?" |
| **Environment** | "Is this on staging, production, or both?" |
| **Current behaviour** | "What is actually happening?" |
| **Expected behaviour** | "What should happen instead?" |
| **Steps to reproduce** | "Walk me through the exact steps to reproduce this — start from login or the entry point." |

### Optional fields (ask if not volunteered)

| Field | Question |
|---|---|
| **FE/BE/FEBE** | "Are changes needed in frontend (FE), backend (BE), or both (FEBE)?" |
| **Workaround** | "Is there a known workaround users or support can use in the meantime?" |
| **Out of scope** | "Is there anything that might look related but is explicitly not part of this bug?" |
| **Open questions** | "Are there any open questions the team needs to discuss before or during the fix?" |
| **Additional context** | "Anything else — frequency, first seen, links to logs or screenshots, related tickets?" |

---

## Ticket Fields

The ticket has three fields:

| Field | Value |
|---|---|
| **Summary** | [FE, BE, or FEBE] - [affected application/component codes] - [Title from above] |
| **Parent** | Bug parent/epic from the tracker configuration, or blank |
| **Description** | All content below — copy in full |

---

## Description Template

Once all required fields are collected, produce the following as the Description. Everything goes here. Use Markdown — most trackers (Jira Cloud, GitHub, GitLab, Linear) render it correctly on paste.

```
## Affected Applications & Who Is Affected
[List each affected application with the user segment or condition impacted.
Example: "**Admin Portal** — all admin users. **Customer Web** — users with an expired subscription."]

## Environment
[Staging / Production / Both]

## Current Behaviour
[What is actually happening — be specific, use observed facts not interpretation.
Example: "Clicking 'Renew' with an expired card on file shows a spinner indefinitely. No error message is displayed."]

## Expected Behaviour
[What should happen instead — describe the correct state clearly enough that a tester can verify it without asking.
Example: "An error message should appear immediately explaining that the saved card has expired and must be updated."]

## Steps to Reproduce
1. [First step — start from login or the entry point]
2. [Next step]
3. [Continue until the bug is visible]

**Result:** [What you see]
**Expected:** [What you should see]

## Workaround
[Known workaround, or omit section if none]

## Out of Scope
[What is explicitly not part of this bug — omit section if not applicable]

## Open Questions
[Questions the team needs to discuss before or during the fix — omit section if none]

## Additional Context
[Frequency, first seen date, links to logs/screenshots, related tickets — omit section if none]
```

---

## Quality Check Before Handing Off

Before presenting the ticket, verify every item:

- [ ] Title is specific — names the broken behaviour, not a vague description ("Renewal hangs when the saved card has expired" not "Payment issue")
- [ ] At least one application is named with the affected user segment
- [ ] At least one environment is stated
- [ ] Current behaviour is factual — no interpretation
- [ ] Expected behaviour is unambiguous — a tester can verify it without asking
- [ ] Steps to reproduce are numbered and complete — a developer who has never touched the feature can follow them

If any required item is missing, ask the user before producing the ticket. Do not produce a ticket with gaps.

---

## Rules

- Never invent repro steps, expected behaviour, or scope — ask.
- If the user is unsure of the environment, default to staging and production until confirmed otherwise.
- Parent comes from the tracker configuration unless the user explicitly overrides it; if none is configured, leave it blank.
- Omit optional sections entirely if there is no content — do not leave empty headings in the description.
- Use Markdown (`##`, `**text**`) as shown.

---

## Related Skills

- `story-ticket` — for improvements and tech-debt tickets (use this skill for bugs only)