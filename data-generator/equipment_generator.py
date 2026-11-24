"""生成制造企业设备管理场景的模拟数据。

用法：
    python equipment_generator.py                     # 生成 CSV 到 data/generated/
    python equipment_generator.py --load              # 先生成再写入 PostgreSQL
    python equipment_generator.py --equipment 2000 --work-orders 20000
"""

from __future__ import annotations

import argparse
import csv
import os
import random
from datetime import datetime, timedelta
from pathlib import Path

DEFAULT_DSN = "postgresql://demo:demo123@localhost:5432/ontology_demo"

FACTORY_NAMES = ["上海总装厂", "苏州精密厂", "武汉冲压厂", "成都电子厂", "天津涂装厂"]
FACTORY_LOCATIONS = ["上海", "苏州", "武汉", "成都", "天津"]
EQUIPMENT_TYPES = ["数控机床", "注塑机", "焊接机器人", "装配线", "检测仪", "空压机"]
STATUSES = ["RUNNING", "IDLE", "MAINTENANCE", "FAULT"]
WORK_ORDER_STATUSES = ["OPEN", "IN_PROGRESS", "DONE"]
PRIORITIES = ["LOW", "MEDIUM", "HIGH"]


def build_factories(rng: random.Random, count: int) -> list[dict]:
    factories = []
    for i in range(count):
        name = FACTORY_NAMES[i % len(FACTORY_NAMES)]
        location = FACTORY_LOCATIONS[i % len(FACTORY_LOCATIONS)]
        factories.append(
            {
                "id": f"FT-{i + 1:03d}",
                "name": f"{name}-{i + 1}",
                "location": location,
            }
        )
    return factories


def build_equipment(rng: random.Random, factories: list[dict], count: int) -> list[dict]:
    equipment = []
    for i in range(count):
        factory = rng.choice(factories)
        equipment.append(
            {
                "id": f"EQ-{i + 1:05d}",
                "name": f"{rng.choice(EQUIPMENT_TYPES)}-{i + 1:04d}",
                "model": f"M{rng.randint(100, 999)}",
                "factory_id": factory["id"],
                "status": rng.choices(STATUSES, weights=[70, 15, 10, 5])[0],
            }
        )
    return equipment


def build_work_orders(
    rng: random.Random, equipment: list[dict], count: int
) -> list[dict]:
    orders = []
    for i in range(count):
        eq = rng.choice(equipment)
        orders.append(
            {
                "id": f"WO-{i + 1:06d}",
                "equipment_id": eq["id"],
                "status": rng.choices(WORK_ORDER_STATUSES, weights=[25, 20, 55])[0],
                "priority": rng.choices(PRIORITIES, weights=[50, 35, 15])[0],
            }
        )
    return orders


def write_csv(rows: list[dict], path: Path, fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def load_to_postgres(
    factories: list[dict], equipment: list[dict], orders: list[dict], dsn: str
) -> None:
    import psycopg

    with psycopg.connect(dsn) as conn, conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO factory (id, name, location)
            VALUES (%(id)s, %(name)s, %(location)s)
            ON CONFLICT (id) DO NOTHING
            """,
            factories,
        )
        cur.executemany(
            """
            INSERT INTO equipment (id, name, model, factory_id, status)
            VALUES (%(id)s, %(name)s, %(model)s, %(factory_id)s, %(status)s)
            ON CONFLICT (id) DO NOTHING
            """,
            equipment,
        )
        cur.executemany(
            """
            INSERT INTO work_order (id, equipment_id, status, priority)
            VALUES (%(id)s, %(equipment_id)s, %(status)s, %(priority)s)
            ON CONFLICT (id) DO NOTHING
            """,
            orders,
        )
        conn.commit()


def main() -> None:
    parser = argparse.ArgumentParser(description="生成设备管理模拟数据")
    parser.add_argument("--factories", type=int, default=5)
    parser.add_argument("--equipment", type=int, default=1000)
    parser.add_argument("--work-orders", type=int, default=10000)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--output-dir", default="data/generated")
    parser.add_argument("--load", action="store_true", help="写入 PostgreSQL")
    parser.add_argument("--dsn", default=os.getenv("DATABASE_URL", DEFAULT_DSN))
    args = parser.parse_args()

    rng = random.Random(args.seed)
    factories = build_factories(rng, args.factories)
    equipment = build_equipment(rng, factories, args.equipment)
    orders = build_work_orders(rng, equipment, args.work_orders)

    out = Path(args.output_dir)
    write_csv(factories, out / "factory.csv", list(factories[0].keys()))
    write_csv(equipment, out / "equipment.csv", list(equipment[0].keys()))
    write_csv(orders, out / "work_order.csv", list(orders[0].keys()))

    if args.load:
        load_to_postgres(factories, equipment, orders, args.dsn)

    print(
        f"已生成 factory={len(factories)}, equipment={len(equipment)}, "
        f"work_order={len(orders)} -> {out}"
    )


if __name__ == "__main__":
    main()
