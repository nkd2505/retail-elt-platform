{{
    config(
        materialized='incremental',
        unique_key='order_item_id',
        incremental_strategy='merge',
        cluster_by=['order_date'],
        on_schema_change='append_new_columns'
    )
}}
-- Grain: one row per order line. Incremental merge keeps daily runs cheap;
-- clustering on order_date prunes micro-partitions for date-filtered BI queries.

with lines as (
    select * from {{ ref('int_order_lines_enriched') }}
    {% if is_incremental() %}
      -- 3-day lookback catches late-arriving status changes (e.g. returns)
      where updated_at > (select dateadd(day, -3, max(updated_at)) from {{ this }})
    {% endif %}
)

select
    l.order_item_id,
    l.order_id,
    c.customer_sk,          -- point-in-time: the customer version valid when the order was placed
    p.product_sk,
    to_number(to_char(l.order_date, 'YYYYMMDD')) as date_key,
    l.order_date,
    l.order_status,
    l.is_reversed,
    l.quantity,
    l.unit_price,
    l.discount_pct,
    l.gross_amount,
    l.net_amount,
    iff(l.is_reversed, 0, l.net_amount)          as recognized_revenue,
    l.updated_at
from lines l
left join {{ ref('dim_customers') }} c
    on  l.customer_id = c.customer_id
    and l.order_date >= c.valid_from::date
    and l.order_date <  c.valid_to::date
left join {{ ref('dim_products') }} p
    on  l.product_id = p.product_id
