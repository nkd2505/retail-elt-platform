"""S3 landing-zone gatekeeper (AWS Lambda, Python 3.12).

Triggered on every new CSV under raw/. Reads only the first few KB of the
object (cheap, no full download), checks the header against the contract,
and moves non-conforming files to quarantine/ + alerts via SNS so a bad
file never reaches Snowflake.
"""
import json
import logging
import os
import urllib.parse

import boto3

log = logging.getLogger()
log.setLevel(logging.INFO)

s3 = boto3.client("s3")
sns = boto3.client("sns")
TOPIC_ARN = os.environ["ALERT_TOPIC_ARN"]

# Mirrors ingestion/schemas.py (packaged separately so the Lambda has no project deps).
ENTITY_COLUMNS = {
    "customers": "customer_id,first_name,last_name,email,city,state,signup_date,updated_at",
    "products": "product_id,product_name,category,unit_price,updated_at",
    "orders": "order_id,customer_id,order_date,status,updated_at",
    "order_items": "order_item_id,order_id,product_id,quantity,unit_price,discount_pct,updated_at",
}


def _quarantine(bucket: str, key: str, reason: str) -> None:
    target = key.replace("raw/", "quarantine/", 1)
    s3.copy_object(Bucket=bucket, Key=target, CopySource={"Bucket": bucket, "Key": key})
    s3.delete_object(Bucket=bucket, Key=key)
    sns.publish(TopicArn=TOPIC_ARN, Subject="Retail ELT: file quarantined",
                Message=json.dumps({"bucket": bucket, "key": key, "moved_to": target, "reason": reason}))
    log.warning("quarantined s3://%s/%s: %s", bucket, key, reason)


def lambda_handler(event, context):
    results = []
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        parts = key.split("/")  # raw/<entity>/dt=YYYY-MM-DD/<file>.csv
        entity = parts[1] if len(parts) >= 4 else None

        if entity not in ENTITY_COLUMNS:
            _quarantine(bucket, key, f"unknown entity '{entity}'")
            results.append({"key": key, "status": "quarantined"})
            continue

        head = s3.get_object(Bucket=bucket, Key=key, Range="bytes=0-4095")["Body"].read().decode("utf-8")
        header = head.splitlines()[0].strip() if head else ""
        if header != ENTITY_COLUMNS[entity]:
            _quarantine(bucket, key, f"header mismatch: got '{header}'")
            results.append({"key": key, "status": "quarantined"})
        else:
            log.info("accepted s3://%s/%s", bucket, key)
            results.append({"key": key, "status": "accepted"})
    return {"results": results}
