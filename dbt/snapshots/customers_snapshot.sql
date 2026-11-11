{#- SCD Type 2: keeps full history of customer attributes (e.g. city moves)
    so revenue can be attributed to where the customer lived at order time. -#}
{% snapshot customers_snapshot %}
{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=True
    )
}}
select * from {{ ref('stg_customers') }}
{% endsnapshot %}
