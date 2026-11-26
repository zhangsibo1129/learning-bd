#!/usr/bin/env python3
"""实验 02：携带列级血缘（ColumnLineageDatasetFacet）。"""
import sys

from ol import column_lineage, dataset, event, new_run_id, post, schema_facet

URL = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:15000/api/v1/lineage"
RUN = new_run_id()

raw = dataset(
    "postgres://demo",
    "raw_orders",
    schema_facet([("order_id", "BIGINT"), ("amount", "DOUBLE"), ("quantity", "INT")]),
)

output_facets = schema_facet(
    [("order_date", "DATE"), ("total_amount", "DOUBLE"), ("items", "INT")]
)
# total_amount 依赖 amount + quantity；items 只依赖 quantity
output_facets.update(
    column_lineage(
        {"total_amount": ["amount", "quantity"], "items": ["quantity"]},
        source_dataset="raw_orders",
    )
)

daily = dataset("iceberg://demo", "daily_orders", output_facets)

print("run_id =", RUN)
print("START  ->", post(event("START", RUN, "daily_orders_build", [raw], [daily]), URL))
print("COMPLETE ->", post(event("COMPLETE", RUN, "daily_orders_build", [raw], [daily]), URL))
