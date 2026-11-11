# Control-M (jobs-as-code)

`retail_elt_jobs.json` defines the same daily flow as the Airflow DAG using the
Control-M Automation API JSON format, for teams standardised on Control-M.

```bash
ctm build  retail_elt_jobs.json      # validate the definition
ctm run    retail_elt_jobs.json      # ad-hoc test run
ctm deploy retail_elt_jobs.json      # promote
```

Design notes
- `%%$ODATE` (YYYYMMDD) is passed straight through; `ingestion/extract_load.py` accepts both
  `YYYYMMDD` and `YYYY-MM-DD`, so the same code runs under both schedulers.
- The loader exits with code **2** on a contract violation vs **1** on any other error, so
  Control-M can route "bad source file" alerts differently from infrastructure failures.
- Validate field names against your Control-M version with `ctm build` before deploying;
  the Automation API schema varies slightly between releases.
