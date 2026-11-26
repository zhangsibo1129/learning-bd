# 实验 04：Schema 演进

**目标**：加列后不重写历史文件，老数据自动为 NULL。

## 步骤

### 1. 加一列并写入新数据

```bash
./scripts/sql.sh 04-schema-evolution.sql
```

预期：

```
| id | customer |   note |
|  1 |    alice |  NULL  |
|  2 |      bob |  NULL  |
|  3 |    carol |  NULL  |
|  4 |     dave |  NULL  |
|  5 |     erin |    vip |
```

老数据没有 `note` 字段，读出来就是 NULL；没有任何回填或重写。

### 2. 用旧快照读新列

用实验 03 的 `SNAP`：

```bash
./scripts/run_inline.sh <<SQL
SELECT count(*) AS old_rows, count(note) AS old_notes
FROM ice.demo.orders /*+ OPTIONS('snapshot-id' = '$SNAP') */;
SQL
```

预期：

```
| old_rows | old_notes |
|        3 |         0 |
```

旧快照里根本不存在 `note`，所以整列为空。

### 3. 为什么不用重写

Iceberg 的每一列都有唯一 ID，schema 演进只改元数据；读旧文件时按列 ID 映射，缺失列补 NULL。

## 破坏性实验：Flink 不支持行级 UPDATE / DELETE

```bash
./scripts/run_inline.sh <<'SQL'
DELETE FROM ice.demo.orders WHERE id = 1;
SQL
```

预期：

```
java.lang.UnsupportedOperationException: Can't perform delete operation ...
because the corresponding dynamic table sink has not yet implemented
org.apache.flink.table.connector.sink.abilities.SupportsRowLevelDelete.
```

Iceberg 表格式本身支持行级删除，但 **Flink 1.20 的 Iceberg Sink 还没实现**。需要更新/删除时，常见替代：

- 使用带主键的表 + upsert 写入（`write.upsert.enabled`）；
- 用 Spark 执行 `DELETE/UPDATE/MERGE`；
- 上层做去重视图。

## 自检

1. 加列时历史 Parquet 文件会被重写吗？
2. 旧快照读新列，为什么是 NULL 而不是报错？
3. 为什么"表格式支持删除"不等于"当前引擎能用"？
