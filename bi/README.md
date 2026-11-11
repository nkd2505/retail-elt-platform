# BI layer: Tableau / Power BI

Both tools connect to Snowflake with the read-only `REPORTER` role and query only the
secure views in `reporting_views.sql`, which sit on the pre-aggregated
`fct_daily_sales` mart, so dashboards stay fast and cheap.

## Dashboard: Retail Sales Overview

| Visual | Source | Notes |
|---|---|---|
| KPI cards: Net Revenue, Orders, AOV, Reversal Rate | `VW_SALES_DASHBOARD` | Compare vs prior period |
| Daily net revenue trend (line) | `VW_SALES_DASHBOARD` | Filter by fiscal quarter |
| Revenue by category (bar) | `VW_SALES_DASHBOARD` | Drill to state |
| Revenue by state (filled map) | `VW_SALES_DASHBOARD` | Uses SCD2 point-in-time state |
| Top customers / at-risk customers (table) | `VW_CUSTOMER_LTV` | At-risk = `days_since_last_order > 60` |

## Connection settings
- **Tableau:** Snowflake connector, warehouse `RETAIL_WH`, role `REPORTER`, Extract refreshed after the daily DAG.
- **Power BI:** Snowflake connector in **DirectQuery** for `VW_SALES_DASHBOARD` (small, aggregated) and Import for `VW_CUSTOMER_LTV`.

## No Snowflake account?
Run `make sample-data` and point Tableau Public or Power BI Desktop (both free) at the
generated CSVs in `data/landing/`, then publish to Tableau Public and add the link to the main README.
