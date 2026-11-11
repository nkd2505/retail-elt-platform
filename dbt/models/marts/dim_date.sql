with spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ var('start_date') ~ "' as date)",
        end_date="dateadd(year, 2, current_date)"
    ) }}
)
select
    cast(date_day as date)                                 as date_day,
    to_number(to_char(date_day, 'YYYYMMDD'))               as date_key,
    year(date_day)                                         as year,
    quarter(date_day)                                      as quarter,
    month(date_day)                                        as month,
    monthname(date_day)                                    as month_name,
    dayname(date_day)                                      as day_name,
    dayofweekiso(date_day) in (6, 7)                       as is_weekend,
    {{ target.database }}.ODS.FN_FISCAL_QUARTER(date_day)  as fiscal_quarter
from spine
