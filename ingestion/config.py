"""Runtime configuration, read from environment variables (12-factor style)."""
import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    s3_bucket: str = os.getenv("RAW_BUCKET", "retail-elt-raw-dev")
    s3_prefix: str = os.getenv("RAW_PREFIX", "raw")
    aws_region: str = os.getenv("AWS_REGION", "us-east-1")

    sf_account: str = os.getenv("SNOWFLAKE_ACCOUNT", "")
    sf_user: str = os.getenv("SNOWFLAKE_USER", "")
    sf_password: str = os.getenv("SNOWFLAKE_PASSWORD", "")
    sf_role: str = os.getenv("SNOWFLAKE_ROLE", "TRANSFORMER")
    sf_warehouse: str = os.getenv("SNOWFLAKE_WAREHOUSE", "RETAIL_WH")
    sf_database: str = os.getenv("SNOWFLAKE_DATABASE", "RETAIL_DB")

    local_landing_dir: str = os.getenv("LANDING_DIR", "data/landing")


settings = Settings()
