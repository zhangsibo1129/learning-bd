# 实验 01：第一条血缘事件

**目标**：看清 OpenLineage 事件的完整结构。

## 步骤

### 1. 启动接收端

```bash
# 终端 A
python3 receiver/server.py
```

预期：

```
[receiver] listening on http://localhost:15000
[receiver] events -> .../components/openlineage/data/events.jsonl
```

### 2. 发送事件

```bash
# 终端 B
python3 emitters/01_minimal.py
```

预期：

```
run_id = 19050b66-...
START  -> (201, '{"status": "ok"}')
COMPLETE -> (201, '{"status": "ok"}')
```

终端 A 会打印两行：

```
[receiver] START ontology-demo.daily_orders_build
[receiver] COMPLETE ontology-demo.daily_orders_build
```

### 3. 看事件内容

```bash
tail -1 data/events.jsonl | python3 -m json.tool | head -40
```

关键字段：

| 字段 | 含义 |
| --- | --- |
| `eventType` | START / COMPLETE |
| `run.runId` | 本次执行的唯一 ID，START 与 COMPLETE 相同 |
| `job.namespace` / `job.name` | 作业标识 |
| `job.facets.sql.query` | 作业执行的 SQL |
| `inputs[].name` | 读了 `raw_orders` |
| `outputs[].name` | 写了 `daily_orders` |
| `outputs[].facets.schema.fields` | 输出表结构 |

### 4. 两条事件的差别

START 带 SQL facet，COMPLETE 只带数据集——START 描述"要做什么"，COMPLETE 表示"做完了"。血缘系统通常以 COMPLETE 为准建图。

## 破坏性实验：发到错误的地址

```bash
python3 emitters/01_minimal.py http://localhost:15999/api/v1/lineage
```

预期：`ConnectionRefusedError` / `URLError`。

说明发送端只是 HTTP 客户端，接收端不存在就失败，不会"静默丢事件"。

## 自检

1. `runId` 为什么 START 和 COMPLETE 要相同？
2. `job` 与 `run` 的区别是什么？
3. 为什么输出数据集要带 schema facet？
4. 事件里没有"作业耗时"，应该加在哪个 facet？
