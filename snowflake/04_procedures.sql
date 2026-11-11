-- =====================================================================
-- 04_procedures.sql : RAW -> ODS incremental merge (Snowflake Scripting)
--
-- For a given batch: dedupe each entity on its business key (latest updated_at
-- wins), MERGE into ODS only when the incoming record is newer (idempotent:
-- safe to re-run the same batch), and write row counts / errors to AUDIT.LOAD_LOG.
-- =====================================================================
USE ROLE SYSADMIN;
USE SCHEMA RETAIL_DB.ODS;

CREATE OR REPLACE PROCEDURE ODS.SP_LOAD_ODS(P_BATCH_ID VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
  v_started   TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP();
  v_step      VARCHAR DEFAULT 'INIT';
  v_rows      NUMBER DEFAULT 0;
  v_total     NUMBER DEFAULT 0;
  v_err       VARCHAR;
BEGIN
  -- Guard: refuse to run if nothing landed for this batch
  SELECT COUNT(*) INTO :v_rows FROM RAW.ORDERS WHERE _batch_id = :P_BATCH_ID;
  IF (v_rows = 0) THEN
    INSERT INTO AUDIT.LOAD_LOG (batch_id, step, status, rows_affected, started_at)
      VALUES (:P_BATCH_ID, 'GUARD', 'SKIPPED_NO_DATA', 0, :v_started);
    RETURN 'SKIPPED: no RAW.ORDERS rows for batch ' || P_BATCH_ID;
  END IF;

  BEGIN TRANSACTION;

  -- ---------- CUSTOMERS ----------
  v_step := 'ODS.CUSTOMERS';
  MERGE INTO ODS.CUSTOMERS t
  USING (
    SELECT * FROM RAW.CUSTOMERS
    WHERE _batch_id = :P_BATCH_ID
    QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY updated_at DESC, _loaded_at DESC) = 1
  ) s
  ON t.customer_id = s.customer_id
  WHEN MATCHED AND s.updated_at > t.updated_at THEN UPDATE SET
    first_name = s.first_name, last_name = s.last_name, email = LOWER(s.email),
    city = s.city, state = s.state, signup_date = s.signup_date, updated_at = s.updated_at,
    _batch_id = s._batch_id, _ods_updated_at = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN INSERT
    (customer_id, first_name, last_name, email, city, state, signup_date, updated_at, _batch_id, _ods_updated_at)
    VALUES (s.customer_id, s.first_name, s.last_name, LOWER(s.email), s.city, s.state, s.signup_date,
            s.updated_at, s._batch_id, CURRENT_TIMESTAMP());
  v_rows := SQLROWCOUNT;  v_total := v_total + v_rows;
  INSERT INTO AUDIT.LOAD_LOG (batch_id, step, status, rows_affected, started_at)
    VALUES (:P_BATCH_ID, :v_step, 'SUCCESS', :v_rows, :v_started);

  -- ---------- PRODUCTS ----------
  v_step := 'ODS.PRODUCTS';
  MERGE INTO ODS.PRODUCTS t
  USING (
    SELECT * FROM RAW.PRODUCTS
    WHERE _batch_id = :P_BATCH_ID
    QUALIFY ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY updated_at DESC, _loaded_at DESC) = 1
  ) s
  ON t.product_id = s.product_id
  WHEN MATCHED AND s.updated_at > t.updated_at THEN UPDATE SET
    product_name = s.product_name, category = s.category, unit_price = s.unit_price,
    updated_at = s.updated_at, _batch_id = s._batch_id, _ods_updated_at = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN INSERT
    (product_id, product_name, category, unit_price, updated_at, _batch_id, _ods_updated_at)
    VALUES (s.product_id, s.product_name, s.category, s.unit_price, s.updated_at, s._batch_id, CURRENT_TIMESTAMP());
  v_rows := SQLROWCOUNT;  v_total := v_total + v_rows;
  INSERT INTO AUDIT.LOAD_LOG (batch_id, step, status, rows_affected, started_at)
    VALUES (:P_BATCH_ID, :v_step, 'SUCCESS', :v_rows, :v_started);

  -- ---------- ORDERS (duplicates in source: latest status wins) ----------
  v_step := 'ODS.ORDERS';
  MERGE INTO ODS.ORDERS t
  USING (
    SELECT * FROM RAW.ORDERS
    WHERE _batch_id = :P_BATCH_ID
    QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC, _loaded_at DESC) = 1
  ) s
  ON t.order_id = s.order_id
  WHEN MATCHED AND s.updated_at > t.updated_at THEN UPDATE SET
    customer_id = s.customer_id, order_date = s.order_date, status = LOWER(s.status),
    updated_at = s.updated_at, _batch_id = s._batch_id, _ods_updated_at = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN INSERT
    (order_id, customer_id, order_date, status, updated_at, _batch_id, _ods_updated_at)
    VALUES (s.order_id, s.customer_id, s.order_date, LOWER(s.status), s.updated_at, s._batch_id, CURRENT_TIMESTAMP());
  v_rows := SQLROWCOUNT;  v_total := v_total + v_rows;
  INSERT INTO AUDIT.LOAD_LOG (batch_id, step, status, rows_affected, started_at)
    VALUES (:P_BATCH_ID, :v_step, 'SUCCESS', :v_rows, :v_started);

  -- ---------- ORDER_ITEMS ----------
  v_step := 'ODS.ORDER_ITEMS';
  MERGE INTO ODS.ORDER_ITEMS t
  USING (
    SELECT * FROM RAW.ORDER_ITEMS
    WHERE _batch_id = :P_BATCH_ID
    QUALIFY ROW_NUMBER() OVER (PARTITION BY order_item_id ORDER BY updated_at DESC, _loaded_at DESC) = 1
  ) s
  ON t.order_item_id = s.order_item_id
  WHEN MATCHED AND s.updated_at > t.updated_at THEN UPDATE SET
    order_id = s.order_id, product_id = s.product_id, quantity = s.quantity, unit_price = s.unit_price,
    discount_pct = s.discount_pct, updated_at = s.updated_at, _batch_id = s._batch_id,
    _ods_updated_at = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN INSERT
    (order_item_id, order_id, product_id, quantity, unit_price, discount_pct, updated_at, _batch_id, _ods_updated_at)
    VALUES (s.order_item_id, s.order_id, s.product_id, s.quantity, s.unit_price, s.discount_pct,
            s.updated_at, s._batch_id, CURRENT_TIMESTAMP());
  v_rows := SQLROWCOUNT;  v_total := v_total + v_rows;
  INSERT INTO AUDIT.LOAD_LOG (batch_id, step, status, rows_affected, started_at)
    VALUES (:P_BATCH_ID, :v_step, 'SUCCESS', :v_rows, :v_started);

  COMMIT;
  RETURN 'SUCCESS: ' || v_total || ' rows merged for batch ' || P_BATCH_ID;

EXCEPTION
  WHEN OTHER THEN
    ROLLBACK;
    v_err := SQLERRM;
    INSERT INTO AUDIT.LOAD_LOG (batch_id, step, status, rows_affected, error_message, started_at)
      VALUES (:P_BATCH_ID, :v_step, 'FAILED', 0, :v_err, :v_started);
    RAISE;  -- surface the failure to Airflow / Control-M
END;
$$;

-- Usage:
-- CALL ODS.SP_LOAD_ODS('2026-10-28');
-- SELECT * FROM AUDIT.LOAD_LOG ORDER BY log_id DESC;
