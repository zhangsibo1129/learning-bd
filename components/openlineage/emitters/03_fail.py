#!/usr/bin/env python3
"""实验 03：作业失败时的 FAIL 事件与 errorMessage facet。"""
import sys

from ol import dataset, error_message_facet, event, new_run_id, post

URL = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:15000/api/v1/lineage"
RUN = new_run_id()

raw = dataset("postgres://demo", "raw_orders")
daily = dataset("iceberg://demo", "daily_orders")

print("run_id =", RUN)
print("START ->", post(event("START", RUN, "daily_orders_build", [raw], [daily]), URL))
print(
    "FAIL  ->",
    post(
        event(
            "FAIL",
            RUN,
            "daily_orders_build",
            [raw],
            [daily],
            run_facets=error_message_facet("java.lang.NumberFormatException: For input string: \"abc\""),
        ),
        URL,
    ),
)
