-- Singular test: a discount can only reduce revenue. Returns offending rows (test passes when empty).
select order_item_id, gross_amount, net_amount
from {{ ref('fct_order_lines') }}
where net_amount > gross_amount + 0.01
