# README Rubric — Frontend

## Purpose

The companion to [`readme-rubric-backend.md`](readme-rubric-backend.md) for **web and mobile frontends** (e.g. an admin console, a customer web app, a partner portal, and any React Native apps). The principle is identical; the section template and the typical content differ.

## The principle (same as backend)

> **A README documents what `package.json`, `.env.*`, `ls`, and `git log` cannot.**

## What's different from backend READMEs

A frontend has no Feign clients, no JPA, no SQS publishers. The high-value content shifts:

| Backend value | Frontend value |
|---|---|
| Feign client → logical service map | URL path prefix → logical service map (`/accounts/api/v1/*` → `accounts-service`) |
| Database choice (JPA vs JDBC) | State management choice (TanStack Query vs Redux vs context) |
| Spring profile per environment | `.env.dev` / `.env.stg` / `.env.prd` per environment |
| Pod size / JVM heap | Bundle size / target browsers |
| OAuth resource server vs custom JWT | Token storage (`localStorage` / `sessionStorage` / cookie), refresh strategy |

## DO include

1. **Purpose and audience.** Back-office operators vs end customers vs partner admins — wildly different products on similar tech.
2. **The URL prefix → logical service map.** Where the admin console hits `/accounts/api/v1/*`, name `accounts-service`. This is the single highest-value piece of frontend documentation — `package.json` has *nothing* about which backends are called.
3. **Auth model.** Where the token lives, how it's refreshed, what happens on 401. Token storage in `localStorage` vs cookie has real security implications and is invisible until you grep for it.
4. **Routing entry points.** A list of top-level routes and the surfaces they correspond to. Not every leaf — just the audience-defining ones (e.g. `login`, the dashboard root, the major operator views).
5. **Build-time environment injection.** Which env vars are baked into the bundle at build time, and which `.env.*` file is the source. Frontends almost always have this and engineers reliably get burned by it.
6. **Deployment shape.** Static asset on S3+CloudFront, or Docker → nginx → EKS, or Vercel, or something else. Drastically affects how a hotfix ships.
7. **Surprising stack choices.** "React 16, frozen on CRA 3.0.1, requires `NODE_OPTIONS=--openssl-legacy-provider`" is *exactly* the kind of warning that saves a new engineer half a day.
8. **Genuine gotchas** — IE 11 still in browserslist, retired-but-imported features, two-of-everything migrations, dead routes, etc.

## DO NOT include

1. **Direct dependencies or their versions.** `package.json` is the source of truth.
2. **Library-by-library stack tour.** "Material UI v4, styled-components, Final Form, react-hook-form, react-router-dom v6, react-router v5, moment, date-fns, …" — drop. A new engineer running the app discovers most of this in the first 30 minutes. Keep only the choices that *constrain future work*: locked major versions, library coexistence that signals migration, archived tooling (CRA 3).
3. **Every view directory.** `views/accountClosure, activationRate, addressType, …` is just `ls src/views/`. Mention only the audience-defining views.
4. **CSS-in-JS or styling minutiae** — unless multiple approaches coexist, in which case one line saying that.
5. **Build-tool internals.** Webpack config, Babel presets, Sonar excludes.
6. **Internal `package.json` hygiene** — unused deps, duplicate declarations. These are cleanup tickets.
7. **Tooling versions that don't constrain anyone.** "react-icons v5", "react-select v5" — `package.json` knows.
8. **Test framework details.** "Uses CRA's default test runner (Jest under the hood)" is fine; "configured with `setupFilesAfterEach` and a custom transformer" is too deep.

## Sniff tests (same shape, frontend-flavoured)

- **Can `cat package.json` answer this?** → cut.
- **Can a `ls src/views/` answer this?** → cut.
- **Will this be wrong when someone bumps a dep?** → cut or generalise.
- **Does this constrain how I'd build a new feature?** → keep.
- **Is this the answer to a "why doesn't X work?" frustration?** → keep.

## Standard section template

| Section | Length | What goes in |
|---|---|---|
| 🧭 Overview | 1 paragraph | What and who, plain English |
| 🧩 Domain Context | 2 paragraphs + bullets | Audience(s), what the user does here |
| 🔄 Role in End-to-End Business Flow | 1–2 paragraphs | Auth flow, API surface contacted, deep-links |
| 🧱 Responsibilities & Boundaries | 2 short lists | Owns / Does NOT own |
| 🔌 Integrations & Dependencies | Structured | Upstream (users), Downstream (URL prefix → logical service), Auth model, External (third-party services / SDKs) |
| 🏗 Technical Overview | Short list | Stack-defining facts only: framework + major version, build tool, language/runtime version, *non-obvious* stack choices |
| 🚀 Running Locally | Code block + 3-line note | Which `.env.*` is the default, port, gotchas (`NODE_OPTIONS` etc.) |
| 🧪 Testing | Code block + 1 line | How to run; mention coverage status only if zero/unusual |
| 📦 Build & Deployment | Code block + bullet list | `build:dev/stg/prd` variants, deployment shape (Docker/nginx/EKS or S3/CloudFront), CI workflow |
| 🔗 Related Modules | Bullet list | Sibling frontends and the backend services this UI is the visible face of |
| ⚠️ Known Behaviour / Edge Cases | 5–10 bullets | Real gotchas only |
| 📝 Review Log | Table | Date / Reviewer / Notes |

## Anti-patterns to avoid

1. **The library stack tour** — listing 15+ libraries with versions in Technical Overview. Cut to: framework + major version, build tool, *non-default* runtime constraints.
2. **The view directory dump** — enumerating every `views/*` directory. Use a one-line summary plus the *audience-defining* views (login, dashboard root, major operator surfaces).
3. **The "Dead but still imported" memorial** — if a feature is retired, spawn a cleanup task. Two or three caveats is fine; a list of ten is noise.
4. **The "Two of everything" laundry list** — naming every pair of coexisting libraries is interesting once. Pick the two that *constrain future work* and explain those.
5. **The OpenAPI / Swagger reference** — frontends consume APIs; they don't document them. Point at the backend service's README if needed.

## Target length

Frontend READMEs in this workspace should land at **120–180 lines**. The same ceiling as backend; same signal to cut at 200.
