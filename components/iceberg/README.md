# Iceberg 组件实验包

独立学习用：本地 warehouse（`file:///warehouse`），通过 Flink SQL 操作 Iceberg，不需要对象存储。

## 1. 定位卡片

| 问题 | 回答 |
| --- | --- |
| 它是什么 | 开放式**表格式**：在 Parquet/ORC 文件之上提供表、快照、Schema 演进、分区与时间旅行 |
| 解决什么 | 数据湖里"文件一堆但不像表"的问题；多引擎共享同一张表；历史版本可追溯 |
| 不解决什么 | 不是存储（文件仍在文件系统/对象存储）、不是计算引擎、不是 Catalog 服务本身 |
| 和相邻组件的边界 | Flink/Spark 负责写与查；RustFS 存文件；Catalog 记表名与 metadata 位置 |

## 2. 核心抽象

| 概念 | 一句话理解 | 容易误解的点 |
| --- | --- | --- |
| Table | 有 schema 的表，底层是文件集合 | 不是数据库表，没有行级原地更新 |
| Snapshot | 某次提交后的完整表状态 | 每次 INSERT/覆盖都会新增一个快照 |
| Manifest | 记录"有哪些数据文件 + 列统计" | 查询裁剪靠它，不是靠文件名 |
| Data File | 实际的 Parquet 文件 | 删除/更新通过新文件 + 删除文件表达 |
| Catalog | 表名 → 当前 metadata 位置 | 可以是 Hadoop、Hive、REST、JDBC |
| 时间旅行 | 按快照读历史版本 | Flink SQL 用 `OPTIONS('snapshot-id'=...)` 提示，不是 `VERSION AS OF` |
| Schema 演进 | 加列/改列后老数据自动兼容 | 老文件不重写，新列读出来是 NULL |
| 分区 | 按列值组织目录，减少扫描 | Flink DDL 只支持物理列的 identity 分区 |

## 3. 快速开始

前置：Flink 相关 jar 需要已下载（复用仓库根目录脚本）。

```bash
cd components/iceberg
../../scripts/fetch-flink-jars.sh      # 首次需要

docker compose build
docker compose up -d

./scripts/sql.sh 01-catalog.sql
```

`scripts/sql.sh` 以 embedded 模式执行 `sql/` 下的文件；warehouse 在命名卷 `iceberg_lab_warehouse`。

临时查询用 `run_inline.sh`，会自动带上常用 SET 与 Catalog 定义：

```bash
./scripts/run_inline.sh <<'SQL'
SELECT count(*) FROM ice.demo.orders;
SQL
```

## 4. 实验清单（按顺序做）

| 实验 | 主题 | 关键收获 |
| --- | --- | --- |
| [01](labs/01-catalog-table.md) | Catalog 与第一张表 | 建表、写入、文件落盘 |
| [02](labs/02-snapshots.md) | 快照 | 每次写入都是一个可追溯版本 |
| [03](labs/03-time-travel.md) | 时间旅行 | 按 snapshot-id 读历史数据 |
| [04](labs/04-schema-evolution.md) | Schema 演进 | 加列后老数据自动 NULL |
| [05](labs/05-partition.md) | 分区表 | 目录结构、分区裁剪 |

每个实验固定写法：目标 → 命令 → **预期现象** → 破坏性实验 → 自检问题。

## 5. 排障清单

| 现象 | 优先检查 |
| --- | --- |
| 构建失败缺 jar | 先执行 `scripts/fetch-flink-jars.sh` |
| `Unable to open BLOB Server ... 6124` | 同容器里还有另一个 SQL Client 没退出：`docker exec iceberg-sql pkill -f SqlClient`，一次只跑一个 |
| INSERT 后客户端立刻退出、没数据 | 需要 `SET 'table.dml-sync' = 'true';` |
| 查 `$snapshots` 语法错误 | 表名要加反引号：`` ice.demo.`orders$snapshots` `` |
| `VERSION AS OF` 解析失败 | Flink SQL 不支持该语法，改用 `/*+ OPTIONS('snapshot-id'='...') */` |
| 想按 `days(ts)` 分区失败 | Flink DDL 只支持物理列 identity 分区；建一个 `dt STRING` 列再分区 |
| 数据乱了想重来 | `docker compose down -v` 后重新 `up -d` |

## 6. 完成标准

能不看文档回答：

- Snapshot、Manifest、Data File 三者的关系是什么？
- 为什么加列不需要重写历史文件？
- 时间旅行读的是文件副本，还是同一批文件的旧视图？
- 分区裁剪发生在哪个环节？
- 为什么说 Iceberg 是"表格式"而不是"存储"？
