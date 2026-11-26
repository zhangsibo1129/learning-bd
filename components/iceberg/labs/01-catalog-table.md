# 实验 01：Catalog 与第一张表

**目标**：建 Catalog、建表、写入，并确认数据真的落成了 Parquet 文件。

## 准备

```bash
../../scripts/fetch-flink-jars.sh     # 首次需要，jar 不入库
docker compose build
docker compose up -d
```

## 步骤

### 1. 建表并写入 3 行

```bash
./scripts/sql.sh 01-catalog.sql
```

预期末尾：

```
|  1 |    alice |   12.5 | 2026-11-01 10:00:00.000000 |
|  2 |      bob |   30.0 | 2026-11-01 11:00:00.000000 |
|  3 |    carol |    7.8 | 2026-11-02 09:30:00.000000 |
3 rows in set
```

### 2. 看文件落盘

```bash
docker exec iceberg-sql sh -c '
  find /warehouse/demo/orders -maxdepth 2 -type f | sort'
```

预期：`metadata/*.metadata.json`、`metadata/*-m0.avro`、`data/*.parquet`。

- `data/*.parquet`：真实数据；
- `metadata/*.json`：表结构、快照列表、当前快照指针；
- `*.avro`：manifest 列表与 manifest，记录"有哪些数据文件"。

### 3. 看 Catalog 只是"指针"

```bash
docker exec iceberg-sql sh -c '
  ls /warehouse/demo/orders/metadata/*.metadata.json'
```

每执行一次写入，metadata 目录就会多一个版本文件；Catalog 里保存的只是"当前用哪个"。

## 破坏性实验：Iceberg 没有主键去重

```bash
./scripts/run_inline.sh <<'SQL'
CREATE TABLE IF NOT EXISTS ice.demo.dup_test (id BIGINT, v STRING);
INSERT INTO ice.demo.dup_test VALUES (1, 'a'), (1, 'b');
SELECT count(*) AS dup_count FROM ice.demo.dup_test;
DROP TABLE IF EXISTS ice.demo.dup_test;
SQL
```

预期：`dup_count = 2`。

普通 Iceberg 表是**追加**语义，不会因为 id 相同就去重；要去重/更新，需要主键 + upsert 配置，或在上游保证唯一。

## 自检

1. Parquet 文件、metadata json、manifest 各自负责什么？
2. 为什么说 Catalog 只是"指向当前 metadata 的指针"？
3. 同一个 id 写两次，Iceberg 会覆盖吗？
