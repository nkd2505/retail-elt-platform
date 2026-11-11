# Contributing

## Workflow
1. Pick a card from `docs/BACKLOG.md`, branch as `feature/RET-<id>-short-name`.
2. Develop against your own dev schema (`DEV_<USER>`, from `profiles.yml`).
3. Open a PR using the template; CI must be green.
4. At least one review. Reviewers comment on *why*, not just *what*, and tag comments
   `nit:` / `suggestion:` / `blocking:` so it's clear what must change.

## Conventions
- **Layers:** `RAW` (as landed) -> `ODS` (current state) -> `staging` -> `intermediate` -> `marts`.
- **Naming:** `stg_<entity>`, `int_<purpose>`, `dim_<entity>`, `fct_<process>`; surrogate keys end `_sk`.
- **Every model** states its grain in a comment and tests its key.
- **SQL style:** lowercase keywords in dbt, explicit column lists (no `select *` in marts).
- **Business rules** (net amount, fiscal calendar) live once, as Snowflake UDFs, and are reused.

## For new joiners
Start with `make dry-run`, then read the models in this order:
`stg_orders` -> `int_order_lines_enriched` -> `fct_order_lines`. Good first issues are tagged in the backlog.
