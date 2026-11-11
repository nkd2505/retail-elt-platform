select
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    coalesce(discount_pct, 0)   as discount_pct,
    updated_at
from {{ source('ods', 'order_items') }}
