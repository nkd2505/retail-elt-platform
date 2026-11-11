-- =====================================================================
-- 03_functions.sql : reusable SQL UDFs (business logic defined once)
-- =====================================================================
USE ROLE SYSADMIN;
USE SCHEMA RETAIL_DB.ODS;

-- Net line amount after discount, rounded to cents.
CREATE OR REPLACE FUNCTION ODS.FN_NET_AMOUNT(qty NUMBER, unit_price NUMBER(10,2), discount_pct NUMBER(5,2))
RETURNS NUMBER(12,2)
LANGUAGE SQL
IMMUTABLE
COMMENT = 'quantity * unit_price * (1 - discount_pct/100), rounded to 2dp'
AS
$$
  ROUND(qty * unit_price * (1 - COALESCE(discount_pct, 0) / 100), 2)
$$;

-- Fiscal quarter label (fiscal year starts Feb 1) - example of a governed business rule.
CREATE OR REPLACE FUNCTION ODS.FN_FISCAL_QUARTER(d DATE)
RETURNS VARCHAR
LANGUAGE SQL
IMMUTABLE
AS
$$
  'FY' || TO_VARCHAR(YEAR(DATEADD(month, 11, d))) || '-Q' || TO_VARCHAR(QUARTER(DATEADD(month, -1, d)))
$$;
