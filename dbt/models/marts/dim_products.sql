select
    {{ dbt_utils.generate_surrogate_key(['product_id']) }} as product_sk,
    product_id,
    product_name,
    category,
    list_price,
    case
        when list_price < 25  then 'Budget'
        when list_price < 100 then 'Mid'
        else 'Premium'
    end as price_band
from {{ ref('stg_products') }}
