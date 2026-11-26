# 实验 03：消费组重平衡

**目标**：亲眼看到消费者增减导致分区重新分配，以及期间的停顿。

## 步骤

### 1. 准备 Topic

```bash
./scripts/kafka.sh kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --topic lab-rebalance --partitions 3 --replication-factor 1

seq 1 30 | ./scripts/kafka.sh kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic lab-rebalance
```

### 2. 启动第一个消费者（终端 A）

```bash
./scripts/kafka.sh kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic lab-rebalance --group rb --from-beginning --property print.partition=true
```

> 新消费组不加 `--from-beginning` 时会从**最新位置**开始消费，之前生产的 30 条不会打印，看起来就像"没有任何反应"。观察重平衡时建议加上 `--from-beginning`，让消费者一启动就有活干。

预期：日志里出现类似 `(org.apache.kafka.clients.consumer.internals.ConsumerCoordinator) [Consumer clientId=..., groupId=rb] Successfully joined group with generation ...`，并看到分区 0/1/2 都归它。

### 3. 启动第二个消费者（终端 B）

用同样命令、同样 `--group rb`。

预期：

- 两个消费者各分到一部分分区（如 A: 0,1 / B: 2）；
- 终端 A 出现 `Revoke previously assigned partitions` 与重新分配日志；
- 期间有短暂停顿。

### 4. 挂掉一个消费者

在终端 B 按 `Ctrl+C`，观察终端 A。

预期：约等一个 `session.timeout.ms`（默认 45 秒）后，A 重新拿到全部 3 个分区。

想加快观察，可在启动时加：

```bash
--consumer-property session.timeout.ms=10000
```

## 破坏性实验：处理太慢被踢出组

用带 `max.poll.interval.ms` 的消费者模拟"处理一条消息卡住太久"：

```bash
./scripts/kafka.sh kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic lab-rebalance --group slow \
  --consumer-property max.poll.interval.ms=5000
```

消费到一半时让它停顿（例如在容器里 `Ctrl+Z` 挂起），超过 5 秒后再恢复。

预期：日志出现 `consumer poll timeout has expired`，该消费者被踢出组并触发重平衡，之后可能重复消费。

关键结论：

- 重平衡 = 分区重新分配，本质是"暂停—再平衡—恢复"；
- 触发来源：成员加入/离开、订阅变化、心跳超时、处理超时；
- 重平衡期间整个组会停顿，消费者越多、越频繁，影响越大；
- 生产环境用**静态成员**（`group.instance.id`）和**协作式再平衡**减少抖动。

## 常见现象：消费者启动后没有任何输出

按顺序排查：

1. **新组 + 没有 `--from-beginning`**：`auto.offset.reset` 默认是 `latest`，只等新消息，历史消息不打印，这是最常见的"没反应"。
2. **组已存在且已消费到末尾**：先查一下：

```bash
./scripts/kafka.sh kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group rb
```

`LAG=0` 且 `CURRENT-OFFSET` 在末尾，就是真的消费完了；要么换组名，要么重置 offset。

3. **Topic 是空的**：容器重建过的话 `lab-rebalance` 和 30 条数据都没了，重新执行步骤 1。

## 自检

1. 3 分区 Topic，4 个消费者同组，会怎样？
2. `session.timeout.ms` 和 `max.poll.interval.ms` 分别防什么？
3. 为什么频繁重平衡会让端到端延迟变大？
