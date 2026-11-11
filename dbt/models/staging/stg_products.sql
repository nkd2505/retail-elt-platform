select
    product_id,
    trim(product_name)  as product_name,
    initcap(category)   as category,
    unit_price          as list_price,
    updated_at
from {{ source('ods', 'products') }}
