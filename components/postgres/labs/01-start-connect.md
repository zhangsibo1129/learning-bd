# 实验 01：启动与 psql 基础

**目标**：连上数据库，认识库、表、以及 psql 的常用元命令。

## 步骤

### 1. 启动并验证

```bash
docker compose up -d
docker compose ps
./scripts/psql.sh -c "select version();"
```

预期：容器 `pg-lab` 为 healthy，返回 `PostgreSQL 16.x`。

### 2. 认识元命令

进入交互终端：

```bash
./scripts/psql.sh
```

在 psql 里依次执行：

```
\l            -- 列出所有数据库
\dt           -- 列出当前库的表
\dn           -- 列出 schema
\?            -- 所有元命令帮助
\q            -- 退出
```

### 3. 导入实验数据

```bash
./scripts/psql.sh -f /sql/seed.sql
```

预期：

```
 table_name | count
------------+--------
 customers  |  20000
 orders     | 200000
```

### 4. 看表结构

```bash
./scripts/psql.sh -c "\d orders"
```

预期：看到 `id / customer_id / amount / status / created_at`，以及主键、外键、CHECK 约束。

### 5. 第一次查询

```bash
./scripts/psql.sh -c "select count(*), round(avg(amount), 2) from orders;"

./scripts/psql.sh -c "
  select id, customer_id, amount, status
  from orders
  order by amount desc
  limit 5;"
```

## 破坏性实验：误删后回滚

```bash
./scripts/psql.sh -c "
  begin;
  delete from orders;
  select count(*) as after_delete from orders;
  rollback;
  select count(*) as after_rollback from orders;"
```

预期：事务内是 0，回滚后又变回 200000。这是"先 BEGIN 再操作"的价值。

## 自检

1. `\dt` 和 `\d orders` 分别看什么？
2. 为什么 `DELETE` 后 `ROLLBACK` 能恢复？
3. `count(*)` 在 20 万行上为什么要扫全表？
