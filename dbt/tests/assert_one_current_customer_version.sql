-- Singular test: SCD2 integrity - every customer has exactly one current row.
select customer_id, count(*) as current_rows
from {{ ref('dim_customers') }}
where is_current
group by customer_id
having count(*) <> 1
