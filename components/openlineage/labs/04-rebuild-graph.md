# 实验 04：从事件重建血缘图

**目标**：把散落的事件聚合成"作业、数据集边、列映射"。

## 步骤

### 1. 确保有数据

```bash
python3 emitters/01_minimal.py
python3 emitters/02_column_lineage.py
python3 emitters/04_summarize.py
```

预期：

```
== 作业 ==
 - ontology-demo.daily_orders_build

== 数据集边 ==
 postgres://demo/raw_orders --[ontology-demo.daily_orders_build]--> iceberg://demo/daily_orders

== 列级血缘 ==
 daily_orders.items <- raw_orders.quantity
 daily_orders.total_amount <- raw_orders.amount, raw_orders.quantity
```

### 2. 聚合规则

`04_summarize.py` 做了三件事：

1. 只取 `eventType == COMPLETE`；
2. 每个 `inputs × outputs` 组合生成一条边，用 `set` 去重；
3. 读取输出数据集的 `columnLineage.fields`，生成字段映射。

这正是血缘服务端（如 Marquez）入库逻辑的简化版：**事件是流水，图是聚合结果**。

### 3. 事件数 vs 图规模

```bash
curl -s http://localhost:15000/api/v1/events
```

再跑一次 `01_minimal.py`，事件数增加，但图不变：

```bash
python3 emitters/01_minimal.py >/dev/null
python3 emitters/04_summarize.py
curl -s http://localhost:15000/api/v1/events
```

预期：作业和边仍然各一条，事件数 +2。

## 破坏性实验：清空事件后重建

```bash
rm -rf data
# 终端 A 重启接收端
python3 receiver/server.py

# 终端 B 只发一条
python3 emitters/02_column_lineage.py
python3 emitters/04_summarize.py
```

预期：图能完整重建。

这说明血缘图是**可重放的派生数据**——只要事件在，图随时能重建；这也是"事件优先"架构的价值。

## 自检

1. 为什么聚合时只取 COMPLETE？
2. 同一条边被上报多次，图里会有多条吗？
3. 事件流和图存储，哪个是"源"？
4. 如果要支持"某次运行失败后重跑"，图应该怎么更新？
