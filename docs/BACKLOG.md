# Backlog (Kanban)

How this project was delivered: small, independently shippable slices, each with
acceptance criteria and a definition of done. WIP limit: 2 items in progress.

## Done
| ID | Story | Acceptance criteria |
|---|---|---|
| RET-1 | As an analyst, I need daily order data in Snowflake | RAW tables load from S3 via COPY with source file + batch lineage |
| RET-2 | As a data engineer, I need bad files stopped at the door | Header/contract check in Python and Lambda; bad files quarantined + SNS alert |
| RET-3 | As an analyst, I need one trusted row per order | `SP_LOAD_ODS` dedupes on key, latest wins, re-runs are idempotent, audit log written |
| RET-4 | As an analyst, I need revenue by where the customer lived at the time | SCD2 snapshot + point-in-time join in `fct_order_lines` |
| RET-5 | As a BI developer, I need a fast dashboard source | `fct_daily_sales` + secure views; REPORTER role read-only |
| RET-6 | As the team, we need the pipeline to run unattended | Airflow DAG with retries/alerts; Control-M equivalent |
| RET-7 | As the team, we need safe changes | CI: ruff, pytest, dbt parse, cfn-lint on every PR |

## Next
| ID | Story |
|---|---|
| RET-8 | Replace the generator with a real source (REST API or Postgres CDC) |
| RET-9 | Snowpipe auto-ingest for near-real-time RAW loads |
| RET-10 | Data observability: row-count anomaly test on `fct_daily_sales` |
| RET-11 | dbt docs site published to S3 static hosting |

## Definition of done
Code reviewed via PR template · tests added · `dbt build` green · docs updated · runbook entry if it pages someone.
