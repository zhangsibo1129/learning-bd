# 实验 02：表设计、约束与 UPSERT

**目标**：用约束挡住脏数据，用 `ON CONFLICT` 实现幂等写入。

## 步骤

### 1. 建一张带约束的表

```bash
./scripts/psql.sh -c "
  create table if not exists inventory (
    sku         text primary key,
    qty         int not null check (qty >= 0),
    updated_at  timestamptz not null default now()
  );"
```

### 2. 插入初始数据

```bash
./scripts/psql.sh -c "
  insert into inventory (sku, qty) values ('A-1', 10), ('B-2', 5)
  on conflict (sku) do nothing;"
```

### 3. 故意违反约束

```bash
./scripts/psql.sh -c "insert into inventory (sku, qty) values ('C-3', -1);"
```

预期：

```
ERROR:  new row for relation "inventory" violates check constraint "inventory_qty_check"
DETAIL:  Failing row contains (C-3, -1, ...).
```

约束在数据库层挡住了脏数据，应用层漏校验也不会写进去。

外键同理：

```bash
./scripts/psql.sh -c "
  insert into orders (customer_id, amount, created_at)
  values (99999999, 100, now());"
```

预期：`violates foreign key constraint`。

### 4. 幂等写入：UPSERT

模拟"同一 SKU 到货 3 件，重复调用也不能重复加"：

```bash
./scripts/psql.sh -c "
  insert into inventory (sku, qty) values ('A-1', 3)
  on conflict (sku) do update
    set qty = inventory.qty + excluded.qty,
        updated_at = now()
  returning sku, qty;"
```

预期：`A-1 | 13`。

再执行一次同样的语句：`A-1 | 16`。

> 如果业务要求"重复请求不重复加"，需要幂等键（如请求 ID）去重，`ON CONFLICT` 只解决"同主键覆盖/累加"。

### 5. 半结构化数据：JSONB

```bash
./scripts/psql.sh -c "
  create table if not exists events (
    id bigserial primary key,
    payload jsonb not null
  );

  insert into events (payload)
  values ('{\"device\":\"EQ-1\",\"temp\":88.5,\"tags\":[\"hot\"]}');

  create index if not exists idx_events_payload on events using gin (payload);

  select payload->>'device' as device,
         (payload->>'temp')::numeric as temp
  from events
  where payload @> '{\"device\":\"EQ-1\"}';"
```

预期：`EQ-1 | 88.5`。

适合"字段经常变"的数据；但频繁用 JSONB 做核心查询，往往说明该拆成正式列。

## 破坏性实验：去掉约束

```bash
./scripts/psql.sh -c "
  alter table inventory drop constraint inventory_qty_check;
  insert into inventory (sku, qty) values ('D-4', -5);
  select * from inventory where sku = 'D-4';"
```

预期：负库存成功写入。约束被移除后，脏数据就进来了——这也是线上误操作的一种来源。

## 自检

1. 应用层校验和数据库约束，为什么两个都要有？
2. `ON CONFLICT DO UPDATE` 和 `DO NOTHING` 分别适合什么场景？
3. 什么情况下不该用 JSONB 存业务字段？
4. 外键会不会拖慢写入？代价是什么？
