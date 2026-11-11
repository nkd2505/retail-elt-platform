-- One row per order line, joined to its order header, with net revenue computed.
select
    oi.order_item_id,
    oi.order_id,
    o.customer_id,
    oi.product_id,
    o.order_date,
    o.order_status,
    o.is_reversed,
    oi.quantity,
    oi.unit_price,
    oi.discount_pct,
    oi.quantity * oi.unit_price                                         as gross_amount,
    {{ net_amount('oi.quantity', 'oi.unit_price', 'oi.discount_pct') }} as net_amount,
    greatest(oi.updated_at, o.updated_at)                               as updated_at
from {{ ref('stg_order_items') }} oi
join {{ ref('stg_orders') }} o using (order_id)
