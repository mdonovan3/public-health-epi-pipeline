"""
Epi Pipeline DAG — replaces cron/poll_and_run.sh when Airflow is active.

Task graph:
    ingest_places ──┐
                    ├──► dbt_run ──► dbt_test
    ingest_epa   ──┘

Both ingestion tasks run in parallel; dbt waits for both to succeed.
If either ingestion task fails, dbt does not run — file stays in data/raw/
for retry on the next trigger.

Schedule: not set (None) — trigger manually or via the Airflow UI.
Switch to schedule="@daily" or a cron string when ready for automated runs.

BashOperator calls Rscript and dbt on the HOST through the mounted project
volume at /opt/epi-pipeline. R, dbt, and ~/.Renviron must be configured
on the host before running.
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import ShortCircuitOperator
import os

PROJECT = "/opt/epi-pipeline"
RAW_DIR = f"{PROJECT}/data/raw"
PROCESSED_DIR = f"{PROJECT}/data/processed"

default_args = {
    "owner": "airflow",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="epi_pipeline",
    description="CDC PLACES + EPA PM2.5 ingestion → dbt run → dbt test",
    default_args=default_args,
    start_date=datetime(2024, 1, 1),
    schedule=None,  # manual trigger — change to "@daily" when ready
    catchup=False,
    tags=["epi", "ingestion", "dbt"],
) as dag:

    # ── Guard: skip the whole run if data/raw/ is empty ──────────────────────
    def raw_dir_has_files():
        files = [f for f in os.listdir(RAW_DIR) if not f.startswith(".")]
        if not files:
            print("data/raw/ is empty — skipping run")
        return bool(files)

    check_raw = ShortCircuitOperator(
        task_id="check_raw_dir",
        python_callable=raw_dir_has_files,
    )

    # ── Ingestion ─────────────────────────────────────────────────────────────
    ingest_places = BashOperator(
        task_id="ingest_places",
        bash_command=f"Rscript {PROJECT}/ingestion/load_places.R",
        env={"DB_PASSWORD_EPI": "{{{{ env['DB_PASSWORD_EPI'] }}}}"},
    )

    ingest_epa = BashOperator(
        task_id="ingest_epa",
        bash_command=f"Rscript {PROJECT}/ingestion/load_epa_pm25.R",
        env={"DB_PASSWORD_EPI": "{{{{ env['DB_PASSWORD_EPI'] }}}}"},
    )

    # ── dbt ───────────────────────────────────────────────────────────────────
    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command=f"cd {PROJECT}/dbt && dbt run --target dev",
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"cd {PROJECT}/dbt && dbt test --target dev",
    )

    # ── Move processed files ──────────────────────────────────────────────────
    # Runs only after dbt_test passes — same lifecycle as the cron script
    archive_files = BashOperator(
        task_id="archive_processed_files",
        bash_command=(
            f"mkdir -p {PROCESSED_DIR} && "
            f"for f in {RAW_DIR}/*.csv; do "
            f"  [ -f \"$f\" ] && mv \"$f\" {PROCESSED_DIR}/$(basename ${{f%.*}})_$(date +%Y%m%d_%H%M%S).csv; "
            f"done"
        ),
    )

    # ── Dependency graph ──────────────────────────────────────────────────────
    check_raw >> [ingest_places, ingest_epa] >> dbt_run >> dbt_test >> archive_files
