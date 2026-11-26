# PostgreSQL 组件实验包

独立学习用，端口 `15432`，库 `demo`，账号 `demo / demo123`。

## 1. 定位卡片

| 问题 | 回答 |
| --- | --- |
| 它是什么 | 关系型 OLTP 数据库：强事务、行级锁、丰富 SQL、可扩展（JSONB/窗口/CTE） |
| 解决什么 | 业务数据的权威存储、事务一致性、复杂查询、约束保证 |
| 不解决什么 | 不是 OLAP 引擎（大宽表聚合会吃力）、不是缓存、不擅长海量日志写入 |
| 和相邻组件的边界 | 业务库/元数据用 PG；分析交给 StarRocks；消息与流处理交给 Kafka/Flink |

## 2. 核心抽象

| 概念 | 一句话理解 | 容易误解的点 |
| --- | --- | --- |
| 表 / 行 | 结构化数据的容器 | 行存储，适合按主键读写，不适合全表扫描聚合 |
| 主键 | 唯一标识一行，自带唯一索引 | 自增主键不等于业务唯一约束 |
| 约束 | NOT NULL / UNIQUE / CHECK / FK | 约束是数据正确性的最后一道防线 |
| 索引 | B-tree 等结构加速定位 | 索引不是越多越好，会拖慢写入、占用空间 |
| MVCC | 读写不互相阻塞，靠版本可见性 | 长事务会阻止 vacuum，导致膨胀 |
| 隔离级别 | Read Committed / Repeatable Read 等 | PG 默认 Read Committed，不是 Serializable |
| EXPLAIN | 查看执行计划与真实耗时 | 看 `actual time` 与 `rows` 估算偏差比看 cost 更重要 |
| VACUUM | 回收死元组、更新统计信息 | 不是"清理日志"，是 MVCC 的必要维护 |

## 3. 快速开始

```bash
cd components/postgres
docker compose up -d

./scripts/psql.sh -c "select version();"
./scripts/psql.sh -f /sql/seed.sql       # 2 万客户 + 20 万订单
./scripts/psql.sh                        # 交互式 psql
```

`scripts/psql.sh` 无参数时进入交互终端；带参数时直接执行，例如 `-c "..."`、`-f /sql/seed.sql`。

## 4. 实验清单（按顺序做）

| 实验 | 主题 | 关键收获 |
| --- | --- | --- |
| [01](labs/01-start-connect.md) | 启动与 psql | 元命令、建库建表、基础查询 |
| [02](labs/02-table-design-upsert.md) | 表设计、约束与 UPSERT | 约束如何挡住脏数据、幂等写入 |
| [03](labs/03-index-explain.md) | 索引与执行计划 | Seq Scan 与 Index Scan 的差别、最左前缀 |
| [04](labs/04-transaction-lock.md) | 事务、锁与隔离级别 | 行锁、快照读、死锁 |
| [05](labs/05-aggregate-window-cte.md) | 聚合、窗口与 CTE | 报表类 SQL 的三件套 |

每个实验固定写法：目标 → 命令 → **预期现象** → 破坏性实验 → 自检问题。

## 5. 常用参考

```sql
-- 查看表大小与索引大小
SELECT pg_size_pretty(pg_total_relation_size('orders'));

-- 查看当前连接与阻塞
SELECT pid, state, wait_event_type, query FROM pg_stat_activity;

-- 查看索引使用情况
SELECT relname, indexrelname, idx_scan FROM pg_stat_user_indexes ORDER BY idx_scan;
```

备份与恢复：

```bash
docker exec pg-lab pg_dump -U demo -d demo -Fc -f /tmp/demo.dump
docker cp pg-lab:/tmp/demo.dump ./demo.dump

docker exec pg-lab createdb -U demo demo_restore
docker cp ./demo.dump pg-lab:/tmp/demo.dump
docker exec pg-lab pg_restore -U demo -d demo_restore /tmp/demo.dump
```

## 6. 排障清单

| 现象 | 优先检查 |
| --- | --- |
| 连不上 | `docker compose ps` 是否 healthy；宿主机端口是 `15432` |
| 查询突然变慢 | `EXPLAIN (ANALYZE, BUFFERS)`；统计信息是否过期（`ANALYZE`） |
| UPDATE 卡住 | 是否有未提交事务持有行锁：`pg_stat_activity` + `pg_locks` |
| 表/索引膨胀 | 长事务、autovacuum 是否跟不上 |
| 死锁 | 应用更新顺序不一致；日志里会打印两个事务的语句 |
| 磁盘占用高 | `pg_total_relation_size`、WAL 目录、未清理的临时文件 |

## 7. 完成标准

能不看文档回答：

- 为什么 UPDATE 某一行会把另一条 UPDATE 卡住？
- 复合索引 `(a, b)` 对只查 `b` 的语句有用吗？
- Read Committed 和 Repeatable Read 在同一个事务里看到的差异是什么？
- 为什么索引能让查询从 7ms 变成 0.04ms？
- `ON CONFLICT DO UPDATE` 解决了什么重复写入问题？
