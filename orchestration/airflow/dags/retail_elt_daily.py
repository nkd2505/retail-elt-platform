"""Daily retail ELT: land -> RAW -> ODS -> dbt (snapshot, build, test).

Idempotent per logical date ({{ ds }}): re-running a day re-lands the same
partition and the ODS MERGE / dbt incremental MERGE converge to the same state,
so backfills are just `airflow dags backfill -s ... -e ...`.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.providers.common.sql.operators.sql import (
    SQLCheckOperator,
    SQLExecuteQueryOperator,
)
from airflow.utils.task_group import TaskGroup

from ingestion.extract_load import build_copy_sql, run as extract_and_land
from ingestion.schemas import LOAD_ORDER

SNOWFLAKE_CONN = "snowflake_default"
DBT_DIR = "/opt/airflow/dbt"
DBT = f"cd {DBT_DIR} && dbt --no-use-colors"
DBT_TARGET = "--target prod"


def _notify_failure(context) -> None:
    # Swap for SlackWebhookHook / SnsPublishOperator in a real deployment.
    ti = context["task_instance"]
    print(f"ALERT: {ti.dag_id}.{ti.task_id} failed for {context['ds']} -> {ti.log_url}")


default_args = {
    "owner": "data-engineering",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "retry_exponential_backoff": True,
    "on_failure_callback": _notify_failure,
}

with DAG(
    dag_id="retail_elt_daily",
    description="Retail orders ELT: S3 -> Snowflake RAW -> ODS -> dbt marts",
    start_date=datetime(2026, 10, 1),
    schedule="0 6 * * *",
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["elt", "snowflake", "dbt"],
    doc_md=__doc__,
) as dag:

    land_to_s3 = PythonOperator(
        task_id="extract_validate_land_s3",
        # Landing only: the Snowflake steps below are separate tasks so each can retry on its own.
        python_callable=lambda ds, **_: extract_and_land(date.fromisoformat(ds), load_snowflake=False),
    )

    with TaskGroup("copy_into_raw") as copy_into_raw:
        for entity in LOAD_ORDER:
            SQLExecuteQueryOperator(
                task_id=f"copy_{entity}",
                conn_id=SNOWFLAKE_CONN,
                sql=build_copy_sql(entity, "{{ ds }}"),
            )

    raw_not_empty = SQLCheckOperator(
        task_id="check_raw_orders_landed",
        conn_id=SNOWFLAKE_CONN,
        sql="SELECT COUNT(*) > 0 FROM RAW.ORDERS WHERE _batch_id = '{{ ds }}'",
    )

    load_ods = SQLExecuteQueryOperator(
        task_id="call_sp_load_ods",
        conn_id=SNOWFLAKE_CONN,
        sql="CALL ODS.SP_LOAD_ODS('{{ ds }}')",
    )

    dbt_freshness = BashOperator(task_id="dbt_source_freshness",
                                 bash_command=f"{DBT} source freshness {DBT_TARGET}")
    dbt_snapshot = BashOperator(task_id="dbt_snapshot",
                                bash_command=f"{DBT} snapshot {DBT_TARGET}")
    # `dbt build` runs models + tests in DAG order: a failing test stops downstream models.
    dbt_build = BashOperator(task_id="dbt_build",
                             bash_command=f"{DBT} build --exclude resource_type:snapshot {DBT_TARGET}")

    land_to_s3 >> copy_into_raw >> raw_not_empty >> load_ods >> dbt_freshness >> dbt_snapshot >> dbt_build
