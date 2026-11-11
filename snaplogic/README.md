# SnapLogic: alternative ingestion path

The Python loader is the reference implementation. For teams that standardise on
SnapLogic, the same RAW load is built as a low-code pipeline that writes into the
**same** RAW tables and lineage columns, so ODS, dbt and BI are unchanged.

## Pipeline: `RETAIL_RAW_ORDERS_LOAD`

| # | Snap | Configuration |
|---|------|---------------|
| 1 | **S3 Browser** | Bucket `retail-elt-raw-<acct>`, path `raw/orders/dt=_batch_date/` (pipeline parameter `batch_date`) |
| 2 | **S3 File Reader** | Reads each listed CSV |
| 3 | **CSV Parser** | Header row on; validate header against the `orders` contract |
| 4 | **Router** | Rows with null `order_id` go to the error path; others continue |
| 5 | **Mapper** | Type casts (`parseInt`, `Date.parse`), adds `_source_file = $['$metadata'].path` and `_batch_id = _batch_date` |
| 6 | **Snowflake - Bulk Load** | Account `RETAIL_DB`, table `RAW.ORDERS`, role `LOADER`, staging via the existing external stage |
| 7 | **Snowflake - Execute** | `CALL ODS.SP_LOAD_ODS('_batch_date')` (last entity pipeline only) |
| E | **Error pipeline** | JSON Formatter -> S3 File Writer to `quarantine/` + Email Sender |

A parent pipeline uses **Pipeline Execute** to run one child per entity in `LOAD_ORDER`
(customers, products, orders, order_items), then triggers the ODS call.

> To show this live: build it in a SnapLogic trial org, export the `.slp` files into this
> folder, and add a screenshot of the canvas here.
