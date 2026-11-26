# 实验 02：Watermark 与窗口

**目标**：看清"窗口什么时候输出"以及"迟到数据为什么消失"。

## 背景：`02-window.sql` 做了什么

- datagen 每秒产生 2 条事件；
- `event_time` 随机落在**过去 10 秒**内（天然乱序）；
- Watermark = `event_time - 2 秒`；
- 按 5 秒滚动窗口统计条数与平均温度。

## 步骤

### 1. 提交作业

```bash
./scripts/flink.sh sql-client.sh -f /opt/flink/sql/02-window.sql
```

### 2. 观察输出

```bash
docker logs -f flink-lab-taskmanager-1 2>&1 | grep --line-buffered -E '^\+I\['
```

预期：

- 每个窗口在**结束时间之后**才输出，不是数据一到就出；
- 5 秒窗口的 `event_count` 大多在 **3～11** 之间，而理论值是 10 条——差额就是被 watermark 判定为"迟到"而丢弃的数据。

### 3. 把 Watermark 放宽

复制一份 SQL，把水位延迟从 2 秒改为 8 秒：

```bash
mkdir -p sql/local
sed "s/INTERVAL '2' SECOND/INTERVAL '8' SECOND/" \
  sql/02-window.sql > sql/local/02-window-late-ok.sql

./scripts/flink.sh sql-client.sh -f /opt/flink/sql/local/02-window-late-ok.sql
```

再看输出：窗口计数明显变大，接近 10。

原因：水位更"保守"，更愿意等迟到数据，代价是窗口输出更晚。

## 破坏性实验：把 Watermark 调成 0

```bash
mkdir -p sql/local
sed "s/INTERVAL '2' SECOND/INTERVAL '0' SECOND/" \
  sql/02-window.sql > sql/local/02-window-zero.sql
```

预期：计数进一步下降——水位几乎不等待乱序数据，窗口只统计到"按时到达"的部分。

## 两个常见误解

| 误解 | 实际 |
| --- | --- |
| Watermark 是真实时间 | 它是"事件时间进度"的估计，可以被人为延迟 |
| 窗口到点就一定输出 | 必须等 watermark 越过窗口结束时间；没有新数据时窗口可能一直不关闭 |

## 自检

1. 为什么 5 秒窗口理论上 10 条，实际却常少于 10？
2. Watermark 延迟调大，准确性、延迟分别怎么变？
3. 如果数据源完全空闲，窗口会输出吗？
4. `event_time` 用处理时间（`PROCTIME()`）替代，会有什么不同？
