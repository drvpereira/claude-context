# Agent Communication Protocol

Message format and agreement thresholds. Referenced from `CLAUDE.md`.

## Agent Communication Protocol

All agent communication follows this format, no exceptions:

`[AGENT NAME] STATUS | FINDING | ACTION`

- **STATUS:** `Clear` / `Issue` / `Blocker` / `Pass`
- **FINDING:** 2–5 sentences — what the problem is, why it matters, what breaks, and the essential impact.
- **ACTION:** 2–3 sentences on what needs to happen. Use `none` only when STATUS is `Clear` or `Pass`.
- **Shorthand:** `Pass — agree with [Agent]` when the agent has nothing new to add beyond a prior agent's output.

No emojis, preamble, acknowledgments, or process narration. Minimum words, maximum signal.

### Agreement Thresholds

`[AGENT NAME] Agreement: 85% | [what would move this to 100%]`

| Score | Meaning |
|---|---|
| 95–100% | No changes required. Proceed. |
| 85–94% | Substantive challenge required before approval. |
| Below 85% | Hard pass. Change required. Reason must be stated. |

### Fallback Rules

**Never assume silently.**

- **Planning:** Ask freely. Surface every unknown before the spec closes.
- **Risk handling:** Spin up adhoc risk agents for assessment and mitigation planning. "We'll handle it later" is not acceptable without a concrete plan documented in the spec.
- **Unresolved risks:** Every unresolved risk must be raised with the user during the planning phase — never carried silently into implementation.
