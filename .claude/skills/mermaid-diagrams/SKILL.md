---
name: mermaid-diagrams
description: Generate Mermaid diagrams locally with the mmdc CLI. Use when adding flow, sequence, ER, or architecture diagrams to a spec.
---

# Mermaid Diagrams

Generate diagrams locally using `mmdc` (Mermaid CLI) — never via AI generation or cloud services. This ensures reproducibility and keeps generation free of external dependencies.

## When to Use
- Adding a flow / sequence / ER / architecture diagram to a spec
- Regenerating a `.png` after the `.mmd` source has changed
- Reviewing a spec for missing diagrams (the architect's diagram-verification gate)

---

**Install:** `npm install -g @mermaid-js/mermaid-cli`

**Generate:** `mmdc -i <file>.mmd -o <file>.png -b white -w 1600`

- **Always use `-b white`** for the background. Transparent backgrounds render invisibly in dark-mode readers (GitHub dark theme, IDE dark themes, mobile dark mode); white guarantees legibility regardless of the reader's theme.
- `-w 1600` keeps text crisp on retina / 4K displays and when zoomed.

**Storage:** depends on context — there are two:
- **Spec diagrams** — store both `.mmd` source and `.png` output in the spec directory alongside the spec file (e.g. `docs/specs/2025.06.10-payments/checkout-flow.mmd`)
- **Canonical documentation diagrams** — store under the relevant audience/domain `diagrams/` folder (e.g. `docs/business/invoicing/diagrams/business-process-happy-path.mmd`). See `.claude/agents/documentation-writer.md` Folder Structure for the canonical layout.

**Naming:** match the doc or spec file name for consistency (e.g. `checkout-flow.mmd` / `checkout-flow.png` for a spec; `business-process-happy-path.mmd` for a canonical doc).

**Regenerate** the `.png` whenever the `.mmd` source changes — never commit a stale diagram.

**Link in spec:** `![Flow](./checkout-flow.png)`

---

## Content rules — business readers, not just engineers

Customer-journey diagrams and business-doc diagrams under `docs/business/` are read by Product, Sales, Finance, Legal, and external stakeholders — not just engineers. Keep the language plain.

- **Do not put HTTP verbs or API paths in arrow labels or notes.** No `POST /api/v1/orders/{id}/cancel`, no `PATCH /api/v1/subscriptions/{id}`, no `GET /invoices/preview/...`. Describe the **business action**: *"Cancel order"*, *"Pause subscription"*, *"Preview next month's invoice"*.
- **Endpoint paths and HTTP semantics belong in the journey's `Where this lives in code` prose section**, not in the diagram. The diagram answers *"what happens, in what order, between which parties"*; the prose answers *"which endpoint, with which annotation, returning which status"*.
- **Domain / processor names are fine** in arrow labels and notes — *"Stripe"*, *"Visa"*, *"payment-webhooks"* — these are part of the business vocabulary the doc establishes.
- **Internal class names, request/response field names, queue / event class names belong in the prose**, not in the diagram. *"Publishes an order-shipped event to a queue"* is fine; `OrderShippedEvent` class name is not.
- When you reference an action that is intentionally **technical** (e.g. *"signing credential carried in the request"*), describe it in business terms (*"the signed order"*) and leave the technical contract for the prose.

If a diagram needs to convey a technical contract for an architectural-review audience, put it under `docs/architecture/` instead of `docs/business/` — different audience, different rules.

---

## Related Skills

- `planning` — full feature specs require diagrams; see also `.claude/templates/spec-template.md`
