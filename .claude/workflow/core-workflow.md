# Core Workflow

The 7-phase procedure every change follows. Referenced from `CLAUDE.md`.

## Workflow

Run this workflow on every request, without exception.
Treat every gate and sign-off as a hard stop — not a formality.

> Planning is where the most leverage is. The more time spent here, the less time wasted later.

### Phases

#### 1. Requirement Gathering & Brainstorming — Planning mode

**a) Initial round — blind, independent feedback:**
- Gather requirements from the user. Ask clarifying questions for any gaps or ambiguities.
- Run all agents in read-only mode to analyse the requirements.
- Each agent works independently — no shared context at this stage.
- Every agent must propose a minimum of 2 solutions and declare a preferred one with rationale.

**Gate ✅:** Every agent has ≥2 solutions and a stated preference with rationale.

**b) Deep brainstorming — iterative, open feedback:**
- Share all context across all agents. Each agent updates their analysis and proposals.
- Agents must challenge each other's ideas — no soft agreement, no shortcuts.
- Iterate until consensus is reached. If not reached after 3 full rounds, escalate to the user with a clear summary of the disagreement.

**Gate ✅:** All agents accept the final cross-challenged plan. User has no new feedback.

#### 2. Spec Definition — Planning mode, iterative until consensus

- Write the spec based on the agreed plan.
- The spec must cover: API contracts, data model (entities, relationships, indexes), testing plan, implementation approach, assumptions, tradeoffs, and open questions.
- Spec is written with **API Contract & Test-Driven Development** as the primary lens.
- Spin up an adhoc **Challenger Agent** to stress-test the spec — its challenge must be thorough and well-reasoned, not a list of vague assumptions.
- All agents cross-check and cross-challenge the spec. No skipping, no soft agreement.
- Your role: eliminate all ambiguity, ensure every concern is addressed, ensure the spec is actionable for both engineers and QA.

**Spec location:** `docs/specs/YYYY.MM.DD-feature-name/YYYY.MM.DD-feature-name.md`
- For a single spec: directory and file share the same name — e.g. `docs/specs/2025.06.10-payments/2025.06.10-payments.md`
- For an epic with sub-features: the directory represents the epic; each file inside is a sub-feature — e.g. `docs/specs/2025.06.10-payments/checkout-flow.md`

**Gate ✅:** Spec covers all required areas in full detail. All agents accept it. User has no new feedback. No unresolved open questions remain.

#### 3. Spec Delivery — Edit mode

- Write the final agreed spec to disk. No new decisions at this stage — everything should already be resolved.
- If anything surfaces as unclear, raise it to the user before writing.

**Gate ✅:** User accepts spec as final. All agents accept it. No unresolved open questions.

#### 4. Test Implementation — Edit mode

- Execute the plan from the spec. Do not re-argue, re-think, or re-interpret it.
- If anything in the spec is unclear, raise it to the user immediately — do not assume.
- QA Agent writes all tests based on the spec. Tests must be written before any implementation begins.
- Tests must compile and fail for the right reasons (assertion errors, not compile errors).
- Delegate scaffold creation only (concrete service shells, repository interfaces, DTO classes, controller stubs — no business logic) to engineers if needed for compilation.
- No business logic at this stage.
- QA Agent self-reviews first, then all agents cross-review.

**Gate ✅:** No business logic implemented. Project compiles. Tests fail for the right reasons. All agents have cross-reviewed the tests.

#### 5. Business Logic Implementation — Edit mode, iterative until all tests pass

- Execute the plan from the spec. Do not re-argue, re-think, or re-interpret it.
- If anything is unclear or missing from the spec, raise it to the user immediately — do not assume. If significant, return to Phase 2 to update the spec before continuing.
- Spin up an adhoc **Reviewer Agent** to compare implementation against the spec line by line.
- All agents cross-check and cross-challenge the implementation. No skipping, no soft agreement.

**Gate ✅:** All tests pass. Implementation matches spec. No unresolved open questions.

#### 6. README Update

- Update the README to reflect any changes to project structure, run commands, or environment setup.
- Run commands must be executable via `package.json` scripts, `Makefile`, `pom.xml`, or `build.gradle` — document them, do not create them here.

**Gate ✅:** README reflects current reality. User accepts it.

#### 7. Commit

- Before creating a branch, fetch the base branch defined in `CLAUDE.md` → Repository settings: `git fetch origin <base branch>`.
- Create your branch from `origin/<base branch>` — never from another feature branch. Open the PR against the configured PR target.
- Branch naming: `feature/<short-description>`, or `hotfix/<short-description>`
  - If a ticket exists, prepend its ID: `feature/PROJ-1234-<short-description>`
  - Lowercase, hyphen-separated.
- Commit message must reference the spec file and describe the feature or fix clearly.
- Prefer atomic commits — one logical change per commit.

**Gate ✅:** Base branch was fetched before branching. Branch created from `origin/<base branch>`. Branch correctly named. Commit references spec. All changes accounted for.

> Use ✅ for every completed gate and ❌ for any failed gate that requires iteration before proceeding.

### Rules & Principles

#### Agreement & Consensus Definition

A phase is signed off only when ALL of the following are true:
- All agents have been run and given the chance to challenge and raise concerns
- All in-scope agents explicitly accept the output as good enough to proceed
- No unresolved blocking objections (vetoes) from any in-scope agent
- All residual tradeoffs are documented in the spec
- User has acknowledged the phase output and has no new feedback or concerns

#### Spec Is Mandatory — No Exceptions

**Every change must have a spec file created or updated before any code is written.**

"Small change", "obvious fix", and "I already know what to do" are not exceptions — they are the most common reasons specs get skipped and code drifts.

- New work → create a new spec file
- Change to existing feature → update the existing spec file
- Bug fix → update the spec under `## Bug Fixes` with reproduction steps, root cause, and fix description — see Bug Fix Workflow for full requirements

If you are about to write code and no spec exists or has been updated — stop. Create or update the spec first.

#### Human as Tie-breaker and Supervisor

The human owns direction. Agents propose, analyse, and implement — but the human supervises everything and takes final precedence.

**The core loop: Generate → Human Reviews → Refine**
1. Agents generate analysis or proposals
2. Human reviews, annotates, and adds direction, ideas, and constraints
3. Agents refine and execute

Human input is especially critical during planning. Agents must actively draw out the human's knowledge before finalising anything.

- Human annotations override agent consensus
- A single veto blocks sign-off and triggers iteration
- Soft agreement ("fine", "okay", "no concerns") is not acceptance

#### Workflow Hard Rules

**Every round:**

1. **Echo check** — pick two agents who agreed: ask each independently to state their reasoning without referencing the other. If reasoning collapses: "Did [Agent]'s answer anchor your position?"
2. **Sycophancy check** — ask the lowest-confidence agent: "What would make you drop your confidence to 70%?" If score increases without a stated reason: "What specifically changed your mind?"
3. **Assumption surface** — rotate one agent each round: "What are you assuming that is not in the spec?" Never ask the same agent twice in a row.
4. **Round 1 unanimous** — if round 1 is unanimous, note it and continue to round 2. Never treat round 1 consensus as final.

**In most rounds:**

5. **Adversarial flip** — rotate one agent to argue the opposite of their stated position.
6. **Simplicity challenge** — one agent: "Is there a simpler version that achieves 90% of the outcome?"

**Conditional — trigger on specific language:**

| Trigger | Response |
|---|---|
| "Fine" / "no concerns" / "okay" | "That is not a position — what do you actually think?" |
| Agent references another before stating own view | "Your view first, independently." |
| "It depends" with no follow-up | "On what? Name the specific conditions." |
| Vague risk language | "Name the specific failure, condition, and consequence." |
| Agent silent for a full round | "[Agent], what is your position and what have you not raised?" |
| Same reasoning repeated | "Rephrase it — give a concrete example not in your previous answer." |
| Solution stated before problem or value | "Problem and business value first. What does the end-user need?" |
| Junior agrees with senior outside their domain | "Experience or deference? Both are valid — state which." |

Agents must challenge each other like professionals in a high-stakes design review. Agreement is only valid when it can be independently explained.

#### Loop Detection

If the same question or position is raised 3+ times without resolution:
1. Stop. State: "Loop detected — [topic] has been raised X times without resolution."
2. Summarise in 3 lines: what the issue is, each side's position, and why it is not resolving.
3. Read `.claude/skills/session-handover/SKILL.md` to produce a handover document, and ask the user to open a fresh session with a direct decision.
4. Never open a fourth round on a looped topic.

#### Conflict: Architect vs Security

Both are equal authorities when their domains intersect:
1. Each states their constraint with a measurable threshold.
2. One round to find a solution satisfying both constraints.
3. If no solution is found: escalate to the user with both constraints, the conflict, and 2+ options with tradeoffs.

#### Escalation to User

After 3 failed rounds: provide a one-sentence blocked decision summary, each agent's position, the core tension, and 2+ options with tradeoffs. Never propose your own resolution.
