-- =====================================================================
-- 02_tables.sql : RAW landing tables, ODS tables, audit log
-- =====================================================================
USE ROLE SYSADMIN;
USE DATABASE RETAIL_DB;

-- ---------- RAW: append-only, every load kept, lineage columns ----------
CREATE TABLE IF NOT EXISTS RAW.CUSTOMERS (
  customer_id NUMBER, first_name VARCHAR, last_name VARCHAR, email VARCHAR,
  city VARCHAR, state VARCHAR, signup_date DATE, updated_at TIMESTAMP_NTZ,
  _source_file VARCHAR, _batch_id VARCHAR, _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);
CREATE TABLE IF NOT EXISTS RAW.PRODUCTS (
  product_id NUMBER, product_name VARCHAR, category VARCHAR, unit_price NUMBER(10,2),
  updated_at TIMESTAMP_NTZ,
  _source_file VARCHAR, _batch_id VARCHAR, _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);
CREATE TABLE IF NOT EXISTS RAW.ORDERS (
  order_id NUMBER, customer_id NUMBER, order_date DATE, status VARCHAR, updated_at TIMESTAMP_NTZ,
  _source_file VARCHAR, _batch_id VARCHAR, _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);
CREATE TABLE IF NOT EXISTS RAW.ORDER_ITEMS (
  order_item_id NUMBER, order_id NUMBER, product_id NUMBER, quantity NUMBER,
  unit_price NUMBER(10,2), discount_pct NUMBER(5,2), updated_at TIMESTAMP_NTZ,
  _source_file VARCHAR, _batch_id VARCHAR, _loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ---------- ODS: one row per business key, current state ----------
CREATE TABLE IF NOT EXISTS ODS.CUSTOMERS (
  customer_id NUMBER PRIMARY KEY, first_name VARCHAR, last_name VARCHAR, email VARCHAR,
  city VARCHAR, state VARCHAR, signup_date DATE, updated_at TIMESTAMP_NTZ,
  _batch_id VARCHAR, _ods_updated_at TIMESTAMP_LTZ
);
CREATE TABLE IF NOT EXISTS ODS.PRODUCTS (
  product_id NUMBER PRIMARY KEY, product_name VARCHAR, category VARCHAR, unit_price NUMBER(10,2),
  updated_at TIMESTAMP_NTZ, _batch_id VARCHAR, _ods_updated_at TIMESTAMP_LTZ
);
CREATE TABLE IF NOT EXISTS ODS.ORDERS (
  order_id NUMBER PRIMARY KEY, customer_id NUMBER, order_date DATE, status VARCHAR,
  updated_at TIMESTAMP_NTZ, _batch_id VARCHAR, _ods_updated_at TIMESTAMP_LTZ
);
CREATE TABLE IF NOT EXISTS ODS.ORDER_ITEMS (
  order_item_id NUMBER PRIMARY KEY, order_id NUMBER, product_id NUMBER, quantity NUMBER,
  unit_price NUMBER(10,2), discount_pct NUMBER(5,2), updated_at TIMESTAMP_NTZ,
  _batch_id VARCHAR, _ods_updated_at TIMESTAMP_LTZ
);

-- ---------- AUDIT ----------
CREATE TABLE IF NOT EXISTS AUDIT.LOAD_LOG (
  log_id NUMBER AUTOINCREMENT,
  batch_id VARCHAR,
  step VARCHAR,
  status VARCHAR,
  rows_affected NUMBER,
  error_message VARCHAR,
  started_at TIMESTAMP_LTZ,
  finished_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);
