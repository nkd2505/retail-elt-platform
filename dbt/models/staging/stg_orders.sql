select
    order_id,
    customer_id,
    order_date,
    lower(status)                                   as order_status,
    lower(status) in ('cancelled', 'returned')      as is_reversed,
    updated_at
from {{ source('ods', 'orders') }}
