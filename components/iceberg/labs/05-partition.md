# 实验 05：分区表

**目标**：看到分区目录与分区裁剪，理解"少扫数据"从哪来。

## 步骤

### 1. 建分区表并写入 3 天数据

```bash
./scripts/sql.sh 05-partition.sql
```

预期：

```
|         dt | cnt |
| 2026-11-01 |   1 |
| 2026-11-02 |   2 |
| 2026-11-03 |   1 |
3 rows in set
```

### 2. 看目录结构

```bash
docker exec iceberg-sql sh -c '
  find /warehouse/demo/events/data -maxdepth 1 -type d | sort'
```

预期：

```
/warehouse/demo/events/data/dt=2026-11-01
/warehouse/demo/events/data/dt=2026-11-02
/warehouse/demo/events/data/dt=2026-11-03
```

每个分区一个目录，目录名就是 `分区列=值`。

### 3. 看分区裁剪

```bash
./scripts/run_inline.sh <<'SQL'
EXPLAIN SELECT * FROM ice.demo.events WHERE dt = '2026-11-02';
SQL
```

预期计划里出现：

```
TableSourceScan(... filter=[=(dt, '2026-11-02')] ...)
```

这个 filter 会下推到 Iceberg，只提交 `dt=2026-11-02` 的 manifest 与文件——其余分区的数据文件根本不会打开。

对照：不带分区条件时，filter 为空，所有文件都要读。

## 破坏性实验：用时间列直接分区

```bash
./scripts/run_inline.sh <<'SQL'
CREATE TABLE IF NOT EXISTS ice.demo.bad_partition (
  id BIGINT,
  ts TIMESTAMP(3)
) PARTITIONED BY (days(ts));
SQL
```

预期：解析失败。

Flink 的 DDL 只支持**物理列的 identity 分区**（`PARTITIONED BY (dt)`）。`days(ts)` 这种隐藏分区变换属于 Iceberg Java API / Spark 的能力，在 Flink DDL 里不可用。

实践做法：在写入前生成 `dt` 列，或由上游计算好分区键。

## 自检

1. 分区列存在哪里？文件内容里也有吗？
2. 分区裁剪发生在客户端还是存储层？
3. 分区太多会有什么问题？
4. 为什么 Flink 里推荐显式 `dt` 列？
