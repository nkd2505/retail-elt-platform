select
    customer_id,
    initcap(trim(first_name))           as first_name,
    initcap(trim(last_name))            as last_name,
    lower(trim(email))                  as email,
    split_part(lower(email), '@', 2)    as email_domain,
    initcap(trim(city))                 as city,
    upper(trim(state))                  as state,
    signup_date,
    updated_at
from {{ source('ods', 'customers') }}
