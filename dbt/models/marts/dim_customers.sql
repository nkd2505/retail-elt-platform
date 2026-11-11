-- SCD Type 2 customer dimension built from the snapshot.
-- The first version of each customer is opened from 1900-01-01 so that orders
-- placed before the customer was first snapshotted still find a matching row.
with versions as (
    select
        *,
        row_number() over (partition by customer_id order by dbt_valid_from) as version_number
    from {{ ref('customers_snapshot') }}
)
select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'dbt_valid_from']) }} as customer_sk,
    customer_id,
    version_number,
    first_name,
    last_name,
    first_name || ' ' || last_name                                           as full_name,
    email,
    email_domain,
    city,
    state,
    signup_date,
    iff(version_number = 1, '1900-01-01'::timestamp, dbt_valid_from)         as valid_from,
    coalesce(dbt_valid_to, '9999-12-31'::timestamp)                          as valid_to,
    dbt_valid_to is null                                                     as is_current
from versions
