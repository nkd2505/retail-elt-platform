-- Pre-aggregated daily KPIs for dashboards (keeps Tableau / Power BI extracts small and fast).
select
    f.order_date,
    d.fiscal_quarter,
    p.category,
    c.state,
    count(distinct f.order_id)                                   as orders,
    count(distinct c.customer_id)                                as customers,
    sum(f.quantity)                                              as units,
    sum(f.gross_amount)                                          as gross_sales,
    sum(f.recognized_revenue)                                    as net_revenue,
    sum(iff(f.is_reversed, f.net_amount, 0))                     as reversed_amount,
    div0(sum(f.recognized_revenue), count(distinct f.order_id))  as avg_order_value
from {{ ref('fct_order_lines') }} f
join      {{ ref('dim_date') }}      d on f.date_key    = d.date_key
left join {{ ref('dim_products') }}  p on f.product_sk  = p.product_sk
left join {{ ref('dim_customers') }} c on f.customer_sk = c.customer_sk
group by 1, 2, 3, 4
