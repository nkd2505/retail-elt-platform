## What & why
<!-- Link the backlog item (e.g. RET-12) and summarise the change -->

## How it was tested
- [ ] `make test` passes
- [ ] `dbt build` on my dev schema passes (paste row counts / test summary)
- [ ] Backfill / re-run is safe (idempotent)

## Reviewer checklist
- [ ] Grain of every new model is stated and tested (`unique` + `not_null` on the key)
- [ ] No credentials or account identifiers committed
- [ ] Incremental logic handles late-arriving data
- [ ] Docs / YAML descriptions updated
