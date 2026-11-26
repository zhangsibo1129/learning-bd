# 实验 05：日志压缩（Compaction）

**目标**：理解 compaction 与 retention 的区别，以及它适用的数据形态。

## 概念先分清

| 策略 | 行为 | 适合 |
| --- | --- | --- |
| `delete` | 按时间/大小整段删除 | 事件流、日志 |
| `compact` | 保留每个 key 的**最新值**，清理旧值 | 状态快照、配置下发、CDC 最新态 |

## 步骤

### 1. 创建 compact Topic

```bash
./scripts/kafka.sh kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --topic lab-compact --partitions 1 --replication-factor 1 \
  --config cleanup.policy=compact \
  --config min.cleanable.dirty.ratio=0.01 \
  --config segment.ms=5000 \
  --config delete.retention.ms=10000
```

### 2. 持续写 12 秒，制造多个日志段

关键点：`segment.ms` 不是定时器，**只有在下一次写入时才会检查是否需要滚动**。写完一批就停，日志段永远不会滚动，也就没有东西可压缩。

```bash
for i in $(seq 1 12); do
  printf 'k1:v%s\nk2:b%s\nk3:c%s\n' $i $i $i
  sleep 1
done | ./scripts/kafka.sh kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic lab-compact \
  --property parse.key=true --property key.separator=:
```

### 3. 停 6 秒后再写一条，触发段滚动

```bash
sleep 6
printf 'k1:tail\n' | ./scripts/kafka.sh kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic lab-compact \
  --property parse.key=true --property key.separator=:
```

### 4. 先看压缩前

```bash
./scripts/kafka.sh kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic lab-compact --from-beginning \
  --property print.key=true --property print.offset=true --timeout-ms 3000
```

预期：k1 的 v1…v12、k2 的 b1…b12、k3 的 c1…c12 全部都在。

### 5. 等待压缩

```bash
sleep 35
```

再执行步骤 4 的命令。

预期：**旧版本消失，只剩最后几条**，例如：

```
Offset:30  k1  v11
Offset:31  k2  b11
Offset:32  k3  c11
Offset:33  k1  v12
Offset:34  k2  b12
Offset:35  k3  c12
Offset:36  k1  tail
```

> offset 不是从 0 开始、也不是连续的，这是正常的：offset 是消息在分区内的**绝对位置**，被压缩掉的记录不会让后面的 offset 回退，日志起始 offset 会前移。
>
> 同时看到 `k1 v12` 和 `k1 tail` 也是正常的：它们还在**活跃段**里，尚未参与压缩。继续写入触发下一次段滚动，再等 15 秒以上，就只剩 `tail`。

最后几条仍然存在是正常的：它们位于**活跃段**，Kafka 从不压缩当前正在写的段。

### 6. 查看段文件

```bash
docker exec kafka-lab ls -l /tmp/kafka-logs/lab-compact-0
```

预期：能看到 `00000000000000000000.log`、`00000000000000000033.log`，以及清理后留下的 `*.log.deleted`、`*.snapshot`。

## 为什么等了一分钟还没压缩

按顺序检查：

1. **只有一个 `.log` 文件** → 段从未滚动，活跃段不会被压缩。必须持续写入或设 `segment.ms` 后继续写。
2. **写完后立刻等待** → 没有任何追加操作触发滚动，等多久都没用。
3. **等待时间 < 15 秒** → 清理线程有 `log.cleaner.backoff.ms`（默认 15 秒）冷却。
4. **Topic 配置没生效** → `kafka-configs.sh --describe --entity-type topics --entity-name lab-compact` 确认 `cleanup.policy=compact`。
5. **只改 `segment.bytes` 且设得太小** → 会直接报 `RecordBatchTooLargeException`，因为段大小不能小于单批消息大小；本实验用时间滚动即可，不必动 `segment.bytes`。

## 破坏性实验：tombstone 删除 key

写入一条 value 为空的记录（控制台里输入 key 后直接回车，value 为空）：

```bash
printf 'k3:\n' | ./scripts/kafka.sh kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic lab-compact \
  --property parse.key=true --property key.separator=:
```

等 `delete.retention.ms`（10 秒）之后再看：k3 会彻底消失。

这就是"CDC 同步删除"的底层机制。

## 自检

1. compaction 能保证"任何时刻都只有一条"吗？为什么？
2. 为什么 compaction 适合 CDC 最新态，而不适合订单事件流？
3. tombstone 为什么要保留 `delete.retention.ms` 一段时间？
4. `cleanup.policy=compact,delete` 同时配置意味着什么？
