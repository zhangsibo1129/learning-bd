# 实验 03：时间旅行

**目标**：不改数据，按快照读回历史版本。

## 前置

从实验 02 的输出里复制**最早**那个 `snapshot_id`，例如：

```bash
export SNAP=3832283852142772501    # 换成你的值
```

## 步骤

### 1. 同时读旧快照与当前表

```bash
./scripts/run_inline.sh <<SQL
SELECT count(*) AS old_count
FROM ice.demo.orders /*+ OPTIONS('snapshot-id' = '$SNAP') */;

SELECT count(*) AS now_count FROM ice.demo.orders;
SQL
```

预期：

```
| old_count |
|         3 |
...
| now_count |
|         4 |
```

同一张表、同一时刻，两个答案——差别只在读哪个快照。

### 2. 对照当前快照

```bash
./scripts/run_inline.sh <<'SQL'
SELECT snapshot_id, operation FROM ice.demo.`orders$snapshots`;
SQL
```

取最新一个 id 再读一次，结果就会和 `now_count` 一致。

### 3. 语法说明

Flink SQL **不支持** `VERSION AS OF` / `TIMESTAMP AS OF`，时间旅行通过动态表选项完成：

```sql
SELECT * FROM ice.demo.orders /*+ OPTIONS('snapshot-id' = '1234567890') */;
```

也可以用 `OPTIONS('as-of-timestamp' = '2026-11-26 06:10:00')` 按时间点读。

## 破坏性实验：读一个不存在的快照

```bash
./scripts/run_inline.sh <<'SQL'
SELECT count(*) FROM ice.demo.orders /*+ OPTIONS('snapshot-id' = '1') */;
SQL
```

预期：报错找不到快照（`Cannot find snapshot with ID 1`）。

说明快照不是"随便编个版本号"，必须真实存在；这也是快照清理后旧查询会失败的原因。

## 自检

1. 时间旅行会复制一份数据吗？
2. 为什么同一张表能同时返回 3 和 4 两种结果？
3. 如果快照被 `expire_snapshots` 清理了，旧查询会怎样？
