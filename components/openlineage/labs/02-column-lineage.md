# 实验 02：列级血缘

**目标**：看清"输出字段来自哪些输入字段"如何表达。

## 步骤

### 1. 发送带列级血缘的事件

```bash
python3 emitters/02_column_lineage.py
```

### 2. 查看 facet

```bash
tail -1 data/events.jsonl | python3 -c "
import json,sys
e=json.load(sys.stdin)['event']
print(json.dumps(e['outputs'][0]['facets']['columnLineage'], ensure_ascii=False, indent=2))"
```

预期：

```json
{
  "columnLineage": {
    "fields": {
      "total_amount": {
        "inputFields": [
          {"namespace": "postgres://demo", "name": "raw_orders", "field": "amount"},
          {"namespace": "postgres://demo", "name": "raw_orders", "field": "quantity"}
        ],
        "transformationType": "DIRECT"
      },
      "items": {
        "inputFields": [
          {"namespace": "postgres://demo", "name": "raw_orders", "field": "quantity"}
        ],
        "transformationType": "DIRECT"
      }
    }
  }
}
```

### 3. 汇总成可读形式

```bash
python3 emitters/04_summarize.py
```

预期：

```
== 列级血缘 ==
 daily_orders.items <- raw_orders.quantity
 daily_orders.total_amount <- raw_orders.amount, raw_orders.quantity
```

### 4. 语义

- `total_amount` 是聚合结果，依赖 `amount` 和 `quantity`；
- `inputFields` 是**数组**，天然支持多来源；
- `transformationType` 可标 `DIRECT` / `INDIRECT`，用于区分"直接搬运"与"间接影响"（如过滤条件）。

## 破坏性实验：只发表级事件

```bash
rm -rf data
# 终端 A 重新启动接收端
python3 receiver/server.py

# 终端 B
python3 emitters/01_minimal.py
python3 emitters/04_summarize.py
```

预期：`== 列级血缘 ==` 下面为空。

表级血缘只能定位到表，无法回答"这个字段从哪来"；列级信息必须由采集端显式上报。

## 自检

1. 一个输出字段依赖多个输入字段，怎么表达？
2. `transformationType` 有什么用？
3. 为什么列级血缘需要 SQL 解析或引擎配合？
4. 聚合字段的 `inputFields` 应该写源字段还是聚合前的中间字段？
