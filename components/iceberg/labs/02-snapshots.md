# 实验 02：快照（Snapshot）

**目标**：看到"每次写入 = 一个新快照"，并读出快照元数据。

## 步骤

### 1. 再写入一行，同时查看快照

```bash
./scripts/sql.sh 02-snapshots.sql
```

预期：

```
|         snapshot_id |               committed_at | operation |
| 3832283852142772501 | 2026-11-26 06:13:39.994000 |    append |
| 2998618139585706236 | 2026-11-26 06:13:46.439000 |    append |
2 rows in set
```

两条快照分别对应 `01` 和 `02` 的两次 INSERT。

> 表名里有 `$`，必须加反引号：`` ice.demo.`orders$snapshots` ``，否则解析器会报错。

### 2. 看 metadata 目录增长

```bash
docker exec iceberg-sql sh -c '
  ls -1 /warehouse/demo/orders/metadata/*.metadata.json'
```

每提交一次，就多一个 metadata 文件；最新那个就是当前表状态。

### 3. 常见元数据表

| 表 | 内容 |
| --- | --- |
| `` `orders$snapshots` `` | 所有快照及 summary |
| `` `orders$history` `` | 快照随时间的变化 |
| `` `orders$files` `` | 当前快照包含的数据文件 |

试一下：

```bash
./scripts/run_inline.sh <<'SQL'
SELECT snapshot_id, operation FROM ice.demo.`orders$snapshots`;
SQL
```

## 破坏性实验：连续写入看快照堆积

```bash
./scripts/run_inline.sh <<'SQL'
INSERT INTO ice.demo.orders VALUES (100, 'tmp', 1.00, TIMESTAMP '2026-11-05 00:00:00');
INSERT INTO ice.demo.orders VALUES (101, 'tmp', 1.00, TIMESTAMP '2026-11-05 00:00:00');
SELECT count(*) AS snapshot_count FROM ice.demo.`orders$snapshots`;
SQL
```

预期：快照数继续增加。生产上需要 `expire_snapshots` 定期清理，否则元数据和旧文件会一直堆积。

> 这一步会给表多写两行，做完实验 02 后建议 `docker compose down -v` 重置再从头做。

## 自检

1. 一次 INSERT 会生成几个快照？
2. 快照里保存的是"数据副本"还是"文件清单"？
3. 为什么快照会无限增长？什么时候需要清理？
