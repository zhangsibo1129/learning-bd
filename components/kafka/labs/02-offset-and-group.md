# 实验 02：Offset 与消费组

**目标**：搞清"消息消费后为什么还在"以及"进度存在哪"。

## 步骤

### 1. 准备 10 条消息

```bash
./scripts/kafka.sh kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --topic lab-offset --partitions 1 --replication-factor 1

seq 1 10 | ./scripts/kafka.sh kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic lab-offset
```

### 2. 用消费组 g1 消费全部

```bash
./scripts/kafka.sh kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic lab-offset --group g1 --from-beginning --timeout-ms 5000
```

预期：打印 1..10，然后因超时退出。

### 3. 查看消费组进度

```bash
./scripts/kafka.sh kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group g1
```

预期：`CURRENT-OFFSET=10`，`LOG-END-OFFSET=10`，`LAG=0`。

### 4. 同组再消费一次

```bash
./scripts/kafka.sh kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic lab-offset --group g1 --timeout-ms 5000
```

预期：**一条都不打印**，因为 group 的 offset 已经在末尾。这就是"消费过不代表删除"。

### 5. 换一个消费组

```bash
./scripts/kafka.sh kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic lab-offset --group g2 --from-beginning --timeout-ms 5000
```

预期：又完整打印 1..10。不同 group 各自维护进度。

### 6. 重置 offset 实现重放

```bash
./scripts/kafka.sh kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --group g1 --topic lab-offset --reset-offsets --to-earliest --execute
```

预期：输出新 offset 为 0。注意：**执行前该组必须没有活跃消费者**。

之后再用 g1 消费即可重放全部消息。

## 常见错误：Consumer group 'g3' does not exist

原因：消费组是**消费者第一次加入时**才创建的。没跑过 g3 消费者，或容器重建过（本实验无数据卷），describe 就会报这个错。

正确顺序是先消费、再查询：

```bash
./scripts/kafka.sh kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic lab-offset --group g3 --from-beginning --timeout-ms 5000

./scripts/kafka.sh kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --list

./scripts/kafka.sh kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group g3
```

## 破坏性实验：中途杀掉消费者

1. 新开终端，用 g3 消费，看到第 3 条时按 `Ctrl+C` 立即中断。
2. 查看进度：

```bash
./scripts/kafka.sh kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group g3
```

预期：`CURRENT-OFFSET` 可能落后于 10，`LAG > 0`。

3. 再启动 g3 消费，观察从哪条继续。

关键结论：

- console consumer 默认 5 秒自动提交一次 offset（`enable.auto.commit=true`）；
- 自动提交 + 处理失败 = **至少一次**语义，可能重复消费；
- 需要精确一次时，要自己控制提交时机或使用事务。

## 自检

1. offset 存在哪里？是消息属性还是消费者状态？
2. 两个 group 读同一 Topic，为什么互不影响？
3. `auto.offset.reset=earliest/latest` 在什么条件下才生效？
4. 消费失败但 offset 已提交，会发生什么？反过来呢？
