# README Rubric

## Purpose

A README is the **first 5 minutes** of a service for a new engineer. It earns its place by answering questions other files answer slowly or not at all.

This rubric applies to **backend services**. For web and mobile frontends, see [`readme-rubric-frontend.md`](readme-rubric-frontend.md).

## The principle

> **A README documents what `pom.xml`, `application.properties`, `ls`, and `git log` cannot.**

If the next reader can answer their question faster by `cat`-ing a file in the repo, the README shouldn't repeat it.

## DO include

1. **Purpose** — what this service is *for*, in one short paragraph. Audience matters: who calls it and why.
2. **Domain context** — the business words this service speaks (Customer, Order, Invoice, Job Execution, etc.).
3. **Role in the end-to-end flow** — what happens when this service is called: triggers → orchestration → side effects → outputs.
4. **Owns / Does NOT own** — the boundary. Where this service stops and the next one starts.
5. **Logical-service relationships** — *which platform service does each Feign client / HTTP call target?* `pom.xml` lists artifacts; `application.properties` lists hostnames; only the README maps them to *logical services*.
6. **Surprising architectural choices** — things that contradict reasonable defaults and would otherwise cost an hour of "wait, where is X?":
   - "Uses custom JWT, not OAuth2 resource server"
   - "Plain JDBC, not JPA"
   - "Bypasses the API gateway"
   - "Default Docker profile is `prd`, not `dev`"
7. **One short block each** for: running locally, testing, building, deploying.
8. **Genuine gotchas** — edge cases that have bitten somebody. *Not* every pom typo, *not* every code smell.
9. **Cross-references to related services** — what should I read next if I'm here for reason X?

## DO NOT include

1. **Direct dependencies or their exact versions.** `pom.xml` is the source of truth, always more current.
2. **File-tree enumeration.** If you find yourself listing `src/main/java/.../foo/`, `bar/`, `baz/` — stop. Mention only directories whose existence or purpose is non-obvious (e.g. `controller/v2/`, `filter/`, `event/`).
3. **Per-property configuration enumeration.** Point at `application-{env}.properties` and call out 2–3 *non-obvious* keys. Don't reproduce the file.
4. **Build-plugin or tooling internals.** JaCoCo, Sonar excludes, Maven exec plugins — these are visible from `pom.xml`.
5. **Internal pom hygiene** ("declared twice", "version mismatch", "unused dep"). These are tracker tickets, not README content.
6. **Versions of "current" or "old" libraries.** "Very old" and "current latest" stale fast. Either state a *specific reason* the version matters ("Java 21 is required at runtime") or leave it to the build file.
7. **Generated content** — controller method lists, OpenAPI summaries. Swagger generates these.
8. **Process steps that have a canonical home elsewhere.** "How to push to develop" belongs in CONTRIBUTING; "what the workflow does" belongs at the top of the workflow file.
9. **Meta-commentary about earlier README versions.** "Previously called X; actually it's Y" → just say "It's Y". The diff is in git.

## Sniff tests

Before writing or keeping a line, ask:

- **Can `cat pom.xml` answer this?** → cut.
- **Will this be wrong in 6 months because someone bumped a version?** → cut or generalise.
- **Does it explain *why*, or just describe *what*?** → keep "why"; cut redundant "what".
- **Would a new engineer notice this is missing if it weren't here?** → if not, cut.
- **Is this a fact that surprised *me* when I learned it?** → keep.

## Standard section template

Every backend service README has these sections, in this order. Each section has a target length.

| Section | Length | What goes in |
|---|---|---|
| 🧭 Overview | 1 paragraph | What and who, in plain English |
| 🧩 Domain Context | 2 paragraphs + bullet list of core concepts | The business vocabulary |
| 🔄 Role in End-to-End Business Flow | 2–3 paragraphs | Triggers → orchestration → outputs |
| 🧱 Responsibilities & Boundaries | 2 short lists | Owns / Does NOT own |
| 🔌 Integrations & Dependencies | Structured | Upstream callers, downstream logical services (mapped from clients), data store, messaging, error contract |
| 🏗 Technical Overview | Short list | Major framework + version-anchoring facts + non-obvious choices only |
| 🚀 Running Locally | Code block + 3-line config note | Single command, point at properties file |
| 🧪 Testing | Code block + 1 line | How to run; mention non-obvious harnesses |
| 📦 Build & Deployment | Code block + bullet list | How it's packaged and where it runs |
| 🔗 Related Modules | Bullet list | Substantive cross-refs only |
| ⚠️ Known Behaviour / Edge Cases | 5–10 bullets | Real gotchas only |
| 📝 Review Log | Table | Date / Reviewer / Notes |

## Anti-patterns to avoid

1. **The dependency archaeology section** — naming every library and version in Technical Overview. Cut to: major framework, language version, anything genuinely non-default.
2. **The repeat-the-Downstream-list problem** — Owns, Does NOT own, Downstream, Related Modules, and Critical Configuration all listing the same set of platform services. Pick one canonical list (Downstream) and reference it from the others.
3. **The dead-code memorial** — listing every retired feature as a Known Behaviour bullet. Two or three of these is informative; ten is noise. If something is truly dead, it should be a spawned cleanup task, not a permanent README scar.
4. **The pom-typo footnote** — internal build issues belong in a tracker, not Known Behaviour.
5. **The "previously called this X" framing** — git already remembers. Just describe reality.

## Target length

Backend service READMEs in this workspace should land at **120–180 lines**. Anything past 200 is a signal to cut.
