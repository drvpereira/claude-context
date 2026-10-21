---
name: database-migrations
description: Flyway / Liquibase migration patterns — file naming, append-only rule, expand-and-contract for breaking changes, separating schema from data migrations, index review, and rollback planning. Use when adding a migration or reviewing schema changes.
---

# Database Migrations

Schema changes are architectural decisions. A bad migration is one of the few things that can take a production system offline irrecoverably. Read this skill before writing the migration, not after the rollback fails.

## When to Use
- Adding a new column, table, or index
- Removing or renaming a column or table
- Backfilling existing data
- Reviewing a teammate's migration before merge
- Diagnosing migration-checksum-mismatch failures

---

## Tooling

This skill assumes **Flyway**. Liquibase patterns are similar but use XML/YAML changelogs. Pick one tool per service and stick to it.

---

## File Naming

| Type | Pattern | Example |
|---|---|---|
| Versioned (most common) | `V<N>__<description>.sql` | `V1__create_orders_table.sql`, `V12__add_customer_email_index.sql` |
| Repeatable | `R__<description>.sql` | `R__create_or_replace_active_orders_view.sql` |
| Undo (rarely used) | `U<N>__<description>.sql` | `U12__revert_customer_email_index.sql` |

**Rules:**
- Version numbers are sequential integers — never gaps, never reuse
- Two underscores separate the version from the description
- Description is lowercase snake_case — `add_customer_email_index`, not `AddCustomerEmailIndex`
- One logical change per file — never bundle unrelated changes

---

## Append-Only — Never Modify

Once a migration is merged to `main` and applied to any non-dev environment, it is immutable. Modifying an existing migration causes a checksum mismatch and Flyway refuses to start.

```sql
-- ❌ NEVER edit an existing migration after merge
-- V12__add_customer_email_index.sql (already applied to staging)
CREATE INDEX idx_customer_email ON customers (email);
-- "let me just add another column too..." — NO. Create V13 instead.

-- ✅ Always append a new migration
-- V13__add_customer_phone_index.sql
CREATE INDEX idx_customer_phone ON customers (phone);
```

**Exception**: If a migration has not yet been merged or applied anywhere outside your local dev, it can still be edited. The line is "applied somewhere shared" — typically that means merged to `main`.

---

## Backwards Compatibility — Expand-and-Contract

Breaking schema changes (column removal, type change, rename, NOT NULL addition) must follow the expand-and-contract pattern. The application is deployed many times during the transition; each step must remain compatible with the previous and next versions.

### Renaming a Column

```sql
-- Step 1 (V20): Expand — add the new column, code writes to both
ALTER TABLE customers ADD COLUMN email_address VARCHAR(255);

-- Step 2: Application release writes to BOTH email and email_address;
--         reads still come from email (the old column)

-- Step 3 (V21): Backfill — populate the new column from the old
UPDATE customers SET email_address = email WHERE email_address IS NULL;

-- Step 4: Application release reads from email_address;
--         still writes to both for safety

-- Step 5 (V22): Contract — drop the old column
ALTER TABLE customers DROP COLUMN email;
```

**The five steps span multiple deploys.** Never collapse them into a single migration — the old version of the application running during the deploy will break.

### Adding a NOT NULL Column

```sql
-- Step 1 (V30): Add as nullable
ALTER TABLE orders ADD COLUMN tenant_id BIGINT;

-- Step 2: Application release writes tenant_id on inserts/updates;
--         old rows still NULL

-- Step 3 (V31): Backfill
UPDATE orders SET tenant_id = (SELECT id FROM tenants WHERE name = 'default') WHERE tenant_id IS NULL;

-- Step 4 (V32): Apply NOT NULL
ALTER TABLE orders ALTER COLUMN tenant_id SET NOT NULL;
```

---

## Schema vs Data Migrations

**Separate schema changes from data migrations.** A single file should do one or the other.

```sql
-- ❌ BAD: schema + data in one file
ALTER TABLE orders ADD COLUMN status_v2 VARCHAR(50);
UPDATE orders SET status_v2 = CASE
    WHEN status = 'NEW' THEN 'PENDING'
    WHEN status = 'DONE' THEN 'COMPLETED'
    ELSE status
END;
ALTER TABLE orders DROP COLUMN status;
```

```sql
-- ✅ GOOD: schema-only
-- V40__add_orders_status_v2_column.sql
ALTER TABLE orders ADD COLUMN status_v2 VARCHAR(50);
```

```sql
-- ✅ GOOD: data-only (separate file, separate review)
-- V41__migrate_orders_status_values.sql
UPDATE orders SET status_v2 = CASE
    WHEN status = 'NEW' THEN 'PENDING'
    WHEN status = 'DONE' THEN 'COMPLETED'
    ELSE status
END;
```

**Why this matters:**
- Data migrations on large tables can take hours — schema migrations should not block startup
- Different review concerns: schema is about correctness; data migration is about scale and lock impact
- If the data migration fails, you can retry it without re-running the schema change

---

## Index Review

Adding an index has write-performance implications. Every new index must be reviewed for:

- **Table size**: how many existing rows? On a billion-row table, `CREATE INDEX` can lock writes for hours unless using `CREATE INDEX CONCURRENTLY` (Postgres)
- **Write rate**: every insert/update on this table pays an index-maintenance cost
- **Index size**: a wide composite index is expensive
- **Cardinality**: a low-cardinality column (e.g. boolean) rarely benefits from an index

```sql
-- ✅ Postgres: concurrent index creation — non-blocking on large tables
CREATE INDEX CONCURRENTLY idx_orders_customer_id_created_at
    ON orders (customer_id, created_at DESC);
```

**Note:** `CONCURRENTLY` cannot run inside a Flyway transaction. Wrap with `-- ${flyway:transactional=false}` or split into a separate migration file.

---

## Rollback Planning

Not every migration is reversible — but every migration must have a rollback plan documented in the spec.

| Migration | Reversible? | Rollback plan |
|---|---|---|
| Add column (nullable) | Yes | Drop the column |
| Add column (NOT NULL with default) | Yes, with care | Drop the column; data may be lost |
| Drop column | No (data lost) | Restore from backup |
| Rename column | Yes, via expand-and-contract | Reverse the steps |
| Add index | Yes | Drop the index |
| Drop table | No (data lost) | Restore from backup; document acceptable RPO |

**If the migration is not trivially reversible, the spec must document:**
- Recovery procedure (restore from backup, point-in-time recovery, replay from event log)
- Acceptable data-loss window (RPO)
- Communication plan for the affected data

---

## Locks and Long-Running Migrations

- `ALTER TABLE` typically takes an `ACCESS EXCLUSIVE` lock on Postgres — blocks reads and writes
- Adding a column with a non-volatile default is fast (Postgres 11+); adding with a volatile default rewrites the table
- Backfilling in batches avoids long-running locks: `UPDATE ... WHERE id BETWEEN x AND y` in chunks, sleep between batches
- For tables under heavy concurrent load, run backfills in a separate application job — not in a migration

---

## Sample Project Layout (Flyway + Spring Boot)

```
src/main/resources/db/migration/
├── V1__create_users_table.sql
├── V2__create_orders_table.sql
├── V3__add_orders_status_index.sql
├── V4__add_users_email_unique_constraint.sql
└── R__active_orders_view.sql
```

```yaml
# application.yml
spring:
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: false  # only set true on the first deploy of an existing DB
    validate-on-migrate: true   # always — fails fast on checksum mismatch
```

---

## Architect Sign-Off

The architect must review every migration before merge — see `.claude/conventions/architecture-standards.md` Migration Review section. Migrations that:
- Drop columns or tables
- Add NOT NULL constraints to existing columns
- Add indexes to tables >10M rows
- Change column types

require explicit architect approval and a documented rollback plan in the spec.

---

## Anti-Patterns

- **Editing a merged migration** — breaks Flyway checksums; deploy fails
- **Schema + data in one file** — different review concerns, different failure modes
- **`CASCADE` drops on foreign keys** — silently removes referencing rows; review intent carefully
- **Renames as a single migration** — breaks the running application during deploy
- **Adding a NOT NULL column without a default** — fails on tables with existing rows
- **Forgetting `CREATE INDEX CONCURRENTLY` on large tables** — production lock-up

---

## Related Skills

- `clean-architecture` — migrations belong in persistence; the application service must not depend on a specific schema version
- `jpa-relationships` — entity mapping changes require corresponding migrations
- `jpa-patterns` — JPA-level concerns (`@Column`, `@Table`) that pair with migrations
- `domain-driven-design` — adding a new aggregate often introduces multiple tables in a single feature
