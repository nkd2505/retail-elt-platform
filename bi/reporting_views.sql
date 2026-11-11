-- =====================================================================
-- BI semantic layer: secure views over the dbt marts for Tableau / Power BI.
-- REPORTER role can read only these; raw/ODS stay hidden from BI users.
-- =====================================================================
USE ROLE TRANSFORMER;
USE SCHEMA RETAIL_DB.MARTS;

CREATE OR REPLACE SECURE VIEW MARTS.VW_SALES_DASHBOARD AS
SELECT
    order_date, fiscal_quarter, category, state,
    orders, customers, units, gross_sales, net_revenue, reversed_amount, avg_order_value,
    DIV0(reversed_amount, gross_sales) AS reversal_rate
FROM MARTS.FCT_DAILY_SALES;

CREATE OR REPLACE SECURE VIEW MARTS.VW_CUSTOMER_LTV AS
SELECT
    c.customer_id,
    c.full_name,
    c.state                              AS current_state,
    MIN(f.order_date)                    AS first_order_date,
    MAX(f.order_date)                    AS last_order_date,
    COUNT(DISTINCT f.order_id)           AS lifetime_orders,
    SUM(f.recognized_revenue)            AS lifetime_revenue,
    DATEDIFF(day, MAX(f.order_date), CURRENT_DATE) AS days_since_last_order
FROM MARTS.FCT_ORDER_LINES f
JOIN MARTS.DIM_CUSTOMERS d ON f.customer_sk = d.customer_sk
JOIN MARTS.DIM_CUSTOMERS c ON c.customer_id = d.customer_id AND c.is_current
GROUP BY 1, 2, 3;

GRANT SELECT ON VIEW MARTS.VW_SALES_DASHBOARD TO ROLE REPORTER;
GRANT SELECT ON VIEW MARTS.VW_CUSTOMER_LTV    TO ROLE REPORTER;
