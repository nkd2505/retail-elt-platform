"""Extract -> validate -> land in S3 -> COPY INTO Snowflake RAW.

This is the "E" and "L" of ELT. Transformation is deliberately left to
Snowflake (stored procedure -> ODS) and dbt (ODS -> warehouse marts).

Usage:
    # Local only: generate + validate, no cloud calls
    python -m ingestion.extract_load --batch-date 2026-10-28 --dry-run

    # Full run (needs AWS + Snowflake credentials in env)
    python -m ingestion.extract_load --batch-date 2026-10-28

--batch-date accepts YYYY-MM-DD or YYYYMMDD (Control-M's %%$ODATE format).
"""
from __future__ import annotations

import argparse
import csv
import logging
import sys
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path

from ingestion.config import settings
from ingestion.generate_data import generate, write_batch
from ingestion.schemas import ENTITY_COLUMNS, LOAD_ORDER

log = logging.getLogger("extract_load")


class ValidationError(Exception):
    """Raised when a landing file breaks its contract. Fail fast, before it reaches the warehouse."""


@dataclass
class FileReport:
    entity: str
    path: Path
    rows: int


# ---------- pure functions (unit-tested) ----------

def parse_batch_date(value: str) -> date:
    for fmt in ("%Y-%m-%d", "%Y%m%d"):
        try:
            return datetime.strptime(value, fmt).date()
        except ValueError:
            continue
    raise argparse.ArgumentTypeError(f"invalid batch date: {value!r}")


def s3_key(entity: str, batch_date: date, filename: str, prefix: str = settings.s3_prefix) -> str:
    return f"{prefix}/{entity}/dt={batch_date.isoformat()}/{filename}"


def validate_file(entity: str, path: Path) -> FileReport:
    """Header must match the contract exactly; file must be non-empty; key column must be populated."""
    expected = ENTITY_COLUMNS[entity]
    with path.open(newline="") as fh:
        reader = csv.reader(fh)
        header = next(reader, None)
        if header != expected:
            raise ValidationError(f"{path.name}: header {header} != expected {expected}")
        rows = 0
        for line_no, row in enumerate(reader, start=2):
            if len(row) != len(expected):
                raise ValidationError(f"{path.name}:{line_no}: expected {len(expected)} fields, got {len(row)}")
            if not row[0].strip():
                raise ValidationError(f"{path.name}:{line_no}: empty primary key {expected[0]}")
            rows += 1
    if rows == 0:
        raise ValidationError(f"{path.name}: file has no data rows")
    return FileReport(entity, path, rows)


def build_copy_sql(entity: str, batch_id: str) -> str:
    """COPY INTO a RAW table, capturing lineage columns (source file + batch id).

    `batch_id` is an ISO date string, or a template such as "{{ ds }}" when
    rendered by Airflow - so the CLI and the DAG load identically.
    """
    cols = ENTITY_COLUMNS[entity]
    positional = ", ".join(f"${i}" for i in range(1, len(cols) + 1))
    return (
        f"COPY INTO RAW.{entity.upper()} ({', '.join(cols)}, _source_file, _batch_id)\n"
        f"FROM (SELECT {positional}, METADATA$FILENAME, '{batch_id}'\n"
        f"      FROM @RAW.S3_RAW_STAGE/{entity}/dt={batch_id}/)\n"
        f"FILE_FORMAT = (FORMAT_NAME = 'RAW.CSV_FMT')\n"
        f"ON_ERROR = 'ABORT_STATEMENT';"
    )


# ---------- side-effecting steps ----------

def upload_to_s3(reports: list[FileReport], batch_date: date) -> None:
    import boto3  # imported lazily so unit tests and dry runs need no AWS SDK

    s3 = boto3.client("s3", region_name=settings.aws_region)
    for r in reports:
        key = s3_key(r.entity, batch_date, r.path.name)
        s3.upload_file(str(r.path), settings.s3_bucket, key,
                       ExtraArgs={"ServerSideEncryption": "AES256"})
        log.info("uploaded s3://%s/%s (%d rows)", settings.s3_bucket, key, r.rows)


def copy_into_snowflake(batch_date: date) -> None:
    import snowflake.connector

    with snowflake.connector.connect(
        account=settings.sf_account, user=settings.sf_user, password=settings.sf_password,
        role=settings.sf_role, warehouse=settings.sf_warehouse, database=settings.sf_database,
    ) as conn, conn.cursor() as cur:
        for entity in LOAD_ORDER:
            cur.execute(build_copy_sql(entity, batch_date.isoformat()))
            log.info("COPY INTO RAW.%s -> %s", entity.upper(), cur.fetchall())
        cur.execute("CALL ODS.SP_LOAD_ODS(%s)", (batch_date.isoformat(),))
        log.info("ODS load: %s", cur.fetchone()[0])


def run(batch_date: date, n_orders: int = 500, dry_run: bool = False,
        load_snowflake: bool = True) -> list[FileReport]:
    """Entry point shared by the CLI, Airflow and Control-M.

    Airflow calls it with load_snowflake=False and runs the COPY / ODS steps as
    separate tasks for finer-grained retries and visibility.
    """
    data = generate(batch_date, n_orders)  # swap for a real API / DB extract in production
    paths = write_batch(data, batch_date, settings.local_landing_dir)
    by_entity = {p.parent.parent.name: p for p in paths}

    reports = [validate_file(e, by_entity[e]) for e in LOAD_ORDER]
    for r in reports:
        log.info("validated %-12s %6d rows  %s", r.entity, r.rows, r.path)

    if dry_run:
        log.info("dry run: skipping S3 upload and Snowflake load")
        return reports
    upload_to_s3(reports, batch_date)
    if load_snowflake:
        copy_into_snowflake(batch_date)
    return reports


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s | %(message)s")
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--batch-date", type=parse_batch_date, default=date.today())
    parser.add_argument("--orders", type=int, default=500)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        run(args.batch_date, args.orders, args.dry_run)
    except ValidationError as exc:
        log.error("contract violation: %s", exc)
        sys.exit(2)  # distinct exit code so schedulers can alert differently


if __name__ == "__main__":
    main()
