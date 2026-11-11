.PHONY: setup sample-data dry-run test lint dbt-deps dbt-build deploy-aws

BATCH ?= $(shell date +%F)

setup:            ## install dev dependencies
	pip install -r requirements-dev.txt

sample-data:      ## generate one day of source CSVs into data/landing/
	python -m ingestion.generate_data --batch-date $(BATCH)

dry-run:          ## extract + validate locally, no cloud calls
	python -m ingestion.extract_load --batch-date $(BATCH) --dry-run

test:             ## unit tests
	pytest -q

lint:             ## python + SQL lint
	ruff check .
	sqlfluff lint snowflake/ --dialect snowflake

dbt-deps:
	cd dbt && dbt deps

dbt-build: dbt-deps  ## snapshot, models and data tests against Snowflake
	cd dbt && dbt snapshot && dbt build --exclude resource_type:snapshot

deploy-aws:       ## deploy S3 bucket, Lambda, SNS, IAM role
	cd aws && sam build && sam deploy --guided
