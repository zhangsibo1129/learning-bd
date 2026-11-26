# 实验 04：数据保留（Retention）

**目标**：理解"消息是否被消费"与"数据是否被删除"完全无关。

## 步骤

### 1. 创建短保留期的 Topic

```bash
./scripts/kafka.sh kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --topic lab-retention --partitions 1 --replication-factor 1 \
  --config cleanup.policy=delete \
  --config retention.ms=15000 \
  --config segment.ms=5000
```

参数说明：

- `retention.ms=15000`：超过 15 秒的段可被删除；
- `segment.ms=5000`：每 5 秒强制滚动一个日志段。**只有已关闭的段才会被删除**，所以必须让它滚动。

### 2. 写入数据并立即消费

```bash
seq 1 20 | ./scripts/kafka.sh kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic lab-retention

./scripts/kafka.sh kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic lab-retention --from-beginning --timeout-ms 3000
```

预期：能读到 20 条。

### 3. 等待 30 秒后再读

```bash
sleep 30

./scripts/kafka.sh kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic lab-retention --from-beginning --timeout-ms 3000
```

预期：**读不到数据或只剩很少几条**（删除是后台任务，有延迟）。

### 4. 查看分区占用

```bash
docker exec kafka-lab du -sh /tmp/kafka-logs/lab-retention-0
```

预期：目录很小，只保留活跃段。

## 破坏性实验：把保留期设为永久

```bash
./scripts/kafka.sh kafka-configs.sh --bootstrap-server localhost:9092 \
  --alter --entity-type topics --entity-name lab-retention \
  --add-config retention.ms=-1
```

再写一批数据、等 30 秒、重新消费：数据不会再消失。

代价：磁盘只增不减——这就是线上常见的"Kafka 磁盘被打满"。

## 自检

1. 为什么设置了 `retention.ms` 却没有立刻删除？
2. `retention.bytes` 和 `retention.ms` 谁先触发谁生效吗？
3. 若消费者停了一周，数据会被保留一周吗？
4. 删除 Topic 和保留策略删除数据，区别是什么？
