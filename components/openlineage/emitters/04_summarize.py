#!/usr/bin/env python3
"""实验 04：从收到的事件里重建血缘图（作业、边、列映射）。"""
import json
from pathlib import Path

EVENTS = Path(__file__).resolve().parent.parent / "data" / "events.jsonl"

if not EVENTS.exists():
    raise SystemExit("还没有事件，先运行 receiver 和 01/02/03")

edges: set[tuple[str, str, str]] = set()
jobs: set[str] = set()
columns: dict[str, list[str]] = {}

for line in EVENTS.read_text(encoding="utf-8").splitlines():
    record = json.loads(line)
    event = record["event"]
    if event.get("eventType") != "COMPLETE":
        continue

    job = f"{event['job']['namespace']}.{event['job']['name']}"
    jobs.add(job)
    for out in event.get("outputs", []):
        for inp in event.get("inputs", []):
            edges.add((f"{inp['namespace']}/{inp['name']}", job, f"{out['namespace']}/{out['name']}"))

        for out_field, spec in out.get("facets", {}).get("columnLineage", {}).get("fields", {}).items():
            deps = [
                f"{f['name']}.{f['field']}" for f in spec.get("inputFields", [])
            ]
            columns[f"{out['name']}.{out_field}"] = deps

print("== 作业 ==")
for job in sorted(jobs):
    print(" -", job)

print("\n== 数据集边 ==")
for upstream, job, downstream in sorted(edges):
    print(f" {upstream} --[{job}]--> {downstream}")

print("\n== 列级血缘 ==")
for target, deps in sorted(columns.items()):
    print(f" {target} <- {', '.join(deps)}")
