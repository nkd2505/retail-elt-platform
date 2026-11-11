{#- Delegates to the governed Snowflake UDF so the business rule lives in exactly one place. -#}
{% macro net_amount(qty, unit_price, discount_pct) -%}
    {{ target.database }}.ODS.FN_NET_AMOUNT({{ qty }}, {{ unit_price }}, {{ discount_pct }})
{%- endmacro %}
