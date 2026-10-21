---
name: story-ticket
description: Draft a complete, tracker-neutral story ticket for an improvement or tech-debt item. Use when the user asks to create a story, write up an improvement, log tech debt, or capture a feature request. Gathers background, acceptance criteria, scope boundaries, and produces ticket-ready Description content.
---

# Story Ticket Skill

Use when the user wants to create a story or improvement ticket in the project's issue tracker.

**Trigger phrases**: "create a story", "create a story ticket", "write up this improvement", "story ticket", "log a tech debt ticket"

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

### Step 1: Determine ticket type

If the user has not already stated the type, ask:

> "Is this an **improvement** (new capability or enhancement to existing behaviour), **tech debt** (internal quality improvement with no visible user change), or something else?"

Use the answer to set the parent:

| Type | Parent |
|---|---|
| Improvement | Improvement parent/epic from the tracker configuration |
| Tech debt | Tech-debt parent/epic from the tracker configuration |
| Unknown / other | *(leave blank — team fills in after)* |

### Required fields

| Field | Question to ask if missing |
|---|---|
| **Title** | "Give me a short title — what is this story about?" |
| **Background** | "What problem or opportunity are we addressing? Why does it matter? What is the desired outcome if we solve it?" |
| **Acceptance criteria** | "What does done look like? List the conditions a tester would check to confirm this story is complete. Placeholders are fine for anything pending team discussion." |

### Optional fields (ask if not volunteered)

| Field | Question |
|---|---|
| **Affected applications** | "Which applications or components are in scope, or is this backend/infrastructure only?" |
| **FE/BE** | "Are changes needed in frontend, backend, or both?" |
| **Out of scope** | "Is there anything adjacent that might seem related but is explicitly not part of this story?" |
| **Open questions** | "Are there open questions or decisions the team needs to discuss before or during delivery?" |
| **Additional context** | "Any other context — translations, links to designs, related tickets, dependencies, or constraints?" |

---

## Ticket Fields

The ticket has two fields:

| Field | Value |
|---|---|
| **Summary** | [FE, BE, or FEBE] - [impacted application/component codes] - [Title from above] |
| **Parent** | [URL from type mapping above, or blank] |
| **Description** | All content below — copy in full |

---

## Description Template

Once all required fields are collected, produce the following as the Description. Everything goes here. Use Markdown — most trackers (Jira Cloud, GitHub, GitLab, Linear) render it correctly on paste.

```
## Background
[2–4 sentences covering:
- What problem or opportunity are we addressing?
- Why does it matter — what breaks, degrades, or is missed without it?
- What is the desired outcome when this is done?]

## Acceptance Criteria
[Each criterion should be independently testable. Write as "Given/When/Then" or plain statements — whichever is clearer for the content.
Placeholders are acceptable where the solution is not yet decided; mark them clearly.]

- AC1: [condition]
- AC2: [condition]
- AC3: *(Placeholder — pending team discussion on approach)*

## Affected Applications
[List each in-scope application, or "Backend / Infrastructure only" if no UI surface.
Omit section if not yet known.]

## Out of Scope
[What is explicitly not part of this story — omit section if not applicable]

## Open Questions
[Questions the team needs to discuss before or during delivery — omit section if none]

## Additional Context
[Translations, links to designs, related tickets, dependencies, constraints — omit section if none]
```

---

## Quality Check Before Handing Off

Before presenting the ticket, verify every item:

- [ ] Title is specific — describes the outcome, not the activity ("Customers can see their order history" not "Add order history feature")
- [ ] Background answers all three: what problem, why it matters, desired outcome
- [ ] At least one acceptance criterion is present — even if others are placeholders
- [ ] Each acceptance criterion is testable — a QA engineer can confirm it passed or failed without asking for clarification
- [ ] Placeholders are clearly marked so the team knows what needs further discussion

If any required item is missing, ask the user before producing the ticket. Do not produce a ticket with gaps.

---

## Rules

- Never invent acceptance criteria or background context — ask.
- Placeholders in acceptance criteria are acceptable and encouraged when the solution is genuinely unknown — mark them clearly rather than writing vague criteria that look complete but are not testable.
- Parent is determined by ticket type from the tracker configuration. If none is configured or the user is unsure, leave it blank rather than guessing.
- Omit optional sections entirely if there is no content — do not leave empty headings in the description.
- Use Markdown (`##`, `**text**`, `-`) as shown.

---

## Related Skills

- `bug-ticket` — for bug tickets (use this skill for improvements and tech debt)
