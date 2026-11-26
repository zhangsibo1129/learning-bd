# 实验 05：聚合、窗口与 CTE

**目标**：掌握报表类 SQL 的三件套：分组聚合、窗口函数、CTE 拆解。

## 步骤

### 1. 分组聚合：各城市 GMV

```bash
./scripts/psql.sh -c "
  select c.city,
         count(*) as orders,
         round(sum(o.amount), 2) as gmv
  from orders o
  join customers c on c.id = o.customer_id
  group by c.city
  order by gmv desc;"
```

预期（数值随随机数据略有差异）：

```
 city | orders |    gmv
------+--------+------------
 深圳 |  40232 | 20305170.39
 杭州 |  39949 | 20275638.53
 上海 |  40192 | 20263384.42
 北京 |  39979 | 20095641.88
 成都 |  39648 | 19975102.61
```

### 2. 窗口函数：每日 GMV 与累计值

```bash
./scripts/psql.sh -c "
  with daily as (
    select created_at::date as d, sum(amount) as gmv
    from orders
    group by 1
  )
  select d,
         round(gmv, 2) as gmv,
         round(sum(gmv) over (order by d), 2) as cumulative
  from daily
  order by d
  limit 4;"
```

预期：

```
     d      |    gmv     | cumulative
------------+------------+------------
 2026-08-28 |  557904.95 |  557904.95
 2026-08-29 | 1135009.57 | 1692914.52
 2026-08-30 | 1095567.22 | 2788481.74
 2026-08-31 | 1150771.21 | 3939252.95
```

`sum(...) over (order by d)` 就是"到当天为止的累计 GMV"，不需要自连接。

### 3. 窗口函数：环比变化（LAG）

```bash
./scripts/psql.sh -c "
  with daily as (
    select created_at::date as d, sum(amount) as gmv
    from orders
    group by 1
  )
  select d,
         round(gmv, 2) as gmv,
         round(gmv - lag(gmv) over (order by d), 2) as diff
  from daily
  order by d desc
  limit 4;"
```

预期：最后一天数值偏小（当天数据还没跑完），`diff` 出现负数——这正说明"按天统计要排除当天"。

### 4. 分组内 Top-N：ROW_NUMBER

```bash
./scripts/psql.sh -c "
  with ranked as (
    select c.city, o.id, o.amount,
           row_number() over (partition by c.city order by o.amount desc) as rn
    from orders o
    join customers c on c.id = o.customer_id
  )
  select city, id, amount
  from ranked
  where rn <= 2
  order by city, rn;"
```

预期：每个城市输出金额最高的 2 笔订单。

## 破坏性实验：窗口查询的执行计划

```bash
./scripts/psql.sh -c "
  explain (analyze, buffers)
  with daily as (
    select created_at::date as d, sum(amount) as gmv
    from orders group by 1
  )
  select d, sum(gmv) over (order by d)
  from daily;"
```

预期：能看到 `WindowAgg` 与前置的 `Sort`/`GroupAggregate`。窗口函数不是"零成本"，它需要有序输入。

把 `order by d` 去掉再对比：累计值失去意义，但计划里少了排序——用来理解"窗口定义决定了执行代价"。

## 自检

1. `GROUP BY` 和窗口函数的本质区别是什么？
2. 累计 GMV 为什么不需要自连接？
3. `row_number` / `rank` / `dense_rank` 在并列值时有何不同？
4. 为什么按天统计经常要排除当天？
