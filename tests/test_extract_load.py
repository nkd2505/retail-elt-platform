from datetime import date
from pathlib import Path

import pytest

from ingestion.extract_load import (
    ValidationError, build_copy_sql, parse_batch_date, s3_key, validate_file,
)
from ingestion.generate_data import generate, write_batch
from ingestion.schemas import ENTITY_COLUMNS

BATCH = date(2026, 10, 28)


def test_parse_batch_date_accepts_iso_and_controlm_formats():
    assert parse_batch_date("2026-10-28") == BATCH
    assert parse_batch_date("20261028") == BATCH


def test_s3_key_is_hive_partitioned():
    assert s3_key("orders", BATCH, "orders_20261028.csv", prefix="raw") == \
        "raw/orders/dt=2026-10-28/orders_20261028.csv"


def test_generated_files_pass_validation(tmp_path: Path):
    paths = write_batch(generate(BATCH, n_orders=50, seed=1), BATCH, tmp_path)
    for p in paths:
        report = validate_file(p.parent.parent.name, p)
        assert report.rows > 0


def test_generator_injects_duplicates_for_ods_dedup():
    orders = generate(BATCH, n_orders=100, seed=1)["orders"]
    ids = [o["order_id"] for o in orders]
    assert len(ids) > len(set(ids)), "expected duplicate order_ids to exercise the ODS MERGE"


def test_bad_header_is_rejected(tmp_path: Path):
    bad = tmp_path / "orders.csv"
    bad.write_text("id,cust,date\n1,2,2026-10-28\n")
    with pytest.raises(ValidationError, match="header"):
        validate_file("orders", bad)


def test_empty_primary_key_is_rejected(tmp_path: Path):
    f = tmp_path / "orders.csv"
    f.write_text(",".join(ENTITY_COLUMNS["orders"]) + "\n,5,2026-10-28,placed,2026-10-28 10:00:00\n")
    with pytest.raises(ValidationError, match="empty primary key"):
        validate_file("orders", f)


def test_copy_sql_captures_lineage_and_partition():
    sql = build_copy_sql("orders", "2026-10-28")
    assert "METADATA$FILENAME" in sql
    assert "dt=2026-10-28" in sql
    assert "_batch_id" in sql
    assert "$5" in sql and "$6" not in sql  # orders has exactly 5 source columns


def test_copy_sql_accepts_airflow_template():
    assert "dt={{ ds }}" in build_copy_sql("customers", "{{ ds }}")
