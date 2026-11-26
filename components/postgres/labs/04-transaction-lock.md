# 实验 04：事务、锁与隔离级别

**目标**：看到行锁、快照读与死锁的真实表现。需要**两个终端**。

打开两个终端，分别进入 psql：

```bash
docker exec -it pg-lab psql -U demo -d demo
```

下面用 **A** 和 **B** 表示两个终端。

## 实验一：未提交的 UPDATE 会阻塞别人

**A：**

```sql
begin;
update orders set amount = amount + 1 where id = 1;
```

（先不要 commit）

**B：**

```sql
update orders set amount = amount + 1 where id = 1;
```

预期：B 卡住不动。

**A：**

```sql
commit;
```

预期：B 立刻返回 `UPDATE 1`。

结论：UPDATE 会加行级排他锁，直到事务结束才释放。线上"某条 SQL 卡住"通常就是有人在事务里忘了提交。

## 实验二：Repeatable Read 的快照读

**A：**

```sql
begin isolation level repeatable read;
select amount from orders where id = 2;
```

**B：**

```sql
update orders set amount = amount + 100 where id = 2;
```

**A：**

```sql
select amount from orders where id = 2;   -- 仍然是旧值
commit;
select amount from orders where id = 2;   -- 现在看到新值
```

结论：Repeatable Read 下，事务内看到的是**开始时的快照**；提交后才看到新数据。这解释了"为什么报表数字和实际不一致"。

## 实验三：制造死锁

**A：**

```sql
begin;
update orders set amount = amount + 1 where id = 1;
```

**B：**

```sql
begin;
update orders set amount = amount + 1 where id = 2;
```

**A：**

```sql
update orders set amount = amount + 1 where id = 2;   -- 阻塞
```

**B：**

```sql
update orders set amount = amount + 1 where id = 1;   -- 触发死锁
```

预期：约 1 秒后，其中一个事务报错：

```
ERROR:  deadlock detected
DETAIL:  Process ... waits for ShareLock on transaction ...; blocked by process ...
HINT:  See server log for query details.
```

另一个事务会继续执行，需要手动 `commit;` 或 `rollback;` 收尾。

结论：死锁不是"数据库坏了"，而是**加锁顺序不一致**。修复方式是统一更新顺序（例如按主键升序）。

## 破坏性实验：长事务拖住一切

**A：**

```sql
begin;
update orders set amount = amount + 1 where id = 3;
-- 然后去喝咖啡，不提交
```

在另一个终端查谁在阻塞：

```bash
./scripts/psql.sh -c "
  select pid, state, wait_event_type, left(query, 60) as query
  from pg_stat_activity
  where datname = 'demo';"
```

预期：能看到 A 的会话处于 `idle in transaction`，其他会话在等锁。

回到 A 执行 `rollback;` 解除。

## 自检

1. 为什么 B 的 UPDATE 会卡在 A 的未提交事务上？
2. Read Committed 与 Repeatable Read 的核心差别是什么？
3. 死锁是谁检测到的？为什么必须牺牲一个事务？
4. 长事务除了锁，还会带来什么副作用？
