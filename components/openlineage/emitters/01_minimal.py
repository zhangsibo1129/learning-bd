#!/usr/bin/env python3
"""实验 01：发送一条完整的 START + COMPLETE 事件。"""
import sys

from ol import dataset, event, new_run_id, post, schema_facet, sql_facet

URL = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:15000/api/v1/lineage"
RUN = new_run_id()

raw = dataset(
    "postgres://demo",
    "raw_orders",
    schema_facet([("order_id", "BIGINT"), ("amount", "DOUBLE"), ("quantity", "INT")]),
)
daily = dataset(
    "iceberg://demo",
    "daily_orders",
    schema_facet([("order_date", "DATE"), ("total_amount", "DOUBLE")]),
)
job_facets = sql_facet(
    "INSERT INTO daily_orders "
    "SELECT order_date, SUM(amount * quantity) AS total_amount "
    "FROM raw_orders GROUP BY order_date"
)

print("run_id =", RUN)
print("START  ->", post(event("START", RUN, "daily_orders_build", [raw], [daily], job_facets=job_facets), URL))
print("COMPLETE ->", post(event("COMPLETE", RUN, "daily_orders_build", [raw], [daily]), URL))
