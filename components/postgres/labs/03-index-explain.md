# 实验 03：索引与执行计划

**目标**：亲眼看到索引如何把"扫 20 万行"变成"读 8 个块"，并理解复合索引的最左前缀。

## 步骤

### 1. 先看不带索引的计划

```bash
./scripts/psql.sh -c "
  explain (analyze, buffers)
  select * from orders where customer_id = 12345;"
```

预期关键行：

```
Seq Scan on orders  (actual time=1.204..7.258 rows=6 loops=1)
  Filter: (customer_id = 12345)
  Rows Removed by Filter: 199994
  Buffers: shared hit=1667
```

解读：扫了 20 万行，只留下 6 行，读了 1667 个数据块。

### 2. 建索引再看

```bash
./scripts/psql.sh -c "create index idx_orders_customer on orders (customer_id);"
./scripts/psql.sh -c "analyze orders;"

./scripts/psql.sh -c "
  explain (analyze, buffers)
  select * from orders where customer_id = 12345;"
```

预期：

```
Bitmap Heap Scan on orders  (actual time=0.019..0.039 rows=6 loops=1)
  Recheck Cond: (customer_id = 12345)
  Buffers: shared hit=9 read=2
  ->  Bitmap Index Scan on idx_orders_customer
```

耗时从 7ms 降到 0.04ms，Buffers 从 1667 降到 11。

### 3. 复合索引：让排序也用上索引

```bash
./scripts/psql.sh -c "
  create index idx_orders_customer_created
  on orders (customer_id, created_at desc);"

./scripts/psql.sh -c "
  explain (analyze, buffers)
  select * from orders
  where customer_id = 12345
  order by created_at desc
  limit 5;"
```

预期：`Index Scan using idx_orders_customer_created`，**没有 Sort 节点**——索引本身已经有序。

### 4. 最左前缀：只查第二列会失效

```bash
./scripts/psql.sh -c "
  explain
  select * from orders where created_at > now() - interval '1 day';"
```

预期：`Seq Scan` 或 `Gather + Parallel Seq Scan`，用不上 `(customer_id, created_at)` 这个复合索引。

## 破坏性实验：索引反而变慢

对低选择性的条件建索引并观察：

```bash
./scripts/psql.sh -c "create index idx_orders_status on orders (status);"
./scripts/psql.sh -c "analyze orders;"
./scripts/psql.sh -c "
  explain (analyze, buffers)
  select count(*) from orders where status = 'paid';"
```

预期：仍然走 Seq Scan。因为 `paid` 占全表约三分之一，走索引再回表反而更贵，优化器会放弃索引。

结论：**索引不是越多越好**，低选择性列、频繁更新的列要谨慎。

## 自检

1. `cost` 和 `actual time` 哪个更能反映真实性能？
2. 复合索引 `(a, b)` 对 `where b = ?` 有用吗？对 `where a = ? and b = ?` 呢？
3. 为什么 `ORDER BY ... LIMIT` 特别适合复合索引？
4. 索引为什么会拖慢 INSERT/UPDATE？
