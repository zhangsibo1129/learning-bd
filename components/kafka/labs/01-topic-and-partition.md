# 实验 01：Topic 与分区

**目标**：亲眼看到"分区是并行单位、也是顺序单位"。

## 步骤

### 1. 创建 3 分区 Topic

```bash
./scripts/kafka.sh kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --topic lab-topic --partitions 3 --replication-factor 1
```

预期：

```
Created topic lab-topic.
```

### 2. 查看 Topic 描述

```bash
./scripts/kafka.sh kafka-topics.sh --bootstrap-server localhost:9092 \
  --describe --topic lab-topic
```

预期：3 行输出，`Partition: 0/1/2`，`Leader: 1`，`Replicas: 1`，`Isr: 1`。

> 单节点下副本因子只能是 1；`Replicas` 与 `Isr` 会相同。

### 3. 带 key 生产 4 条消息

```bash
printf 'k1:v1\nk2:v2\nk3:v3\nk1:v4\n' | ./scripts/kafka.sh kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic lab-topic \
  --property parse.key=true --property key.separator=:
```

### 4. 带分区与 offset 消费

```bash
./scripts/kafka.sh kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic lab-topic --from-beginning \
  --property print.key=true --property print.partition=true --property print.offset=true
```

预期（分区号由 key 的哈希决定，具体数字可能不同）：

```
Partition:2  Offset:0  k1  v1
Partition:0  Offset:0  k2  v2
Partition:1  Offset:0  k3  v3
Partition:2  Offset:1  k1  v4
```

关键观察：**k1 的两条消息落在同一个分区且 offset 递增**；k2/k3 的分区号由 `hash(key) % 分区数` 决定。

### 5. 看磁盘上的分区目录

```bash
docker exec kafka-lab ls /tmp/kafka-logs | grep lab-topic
```

预期：

```
lab-topic-0
lab-topic-1
lab-topic-2
```

## 破坏性实验：加分区会让同 key 换分区

```bash
./scripts/kafka.sh kafka-topics.sh --bootstrap-server localhost:9092 \
  --alter --topic lab-topic --partitions 4

printf 'k1:v5\n' | ./scripts/kafka.sh kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic lab-topic \
  --property parse.key=true --property key.separator=:

./scripts/kafka.sh kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic lab-topic --from-beginning \
  --property print.key=true --property print.partition=true --property print.offset=true
```

预期：`k1:v5` 可能出现在与 `k1:v1`、`k1:v4` 不同的分区。

原因：分区号 = `hash(key) % 分区数`，分母变了，结果就变了。**结论：分区数只增不减，且扩容会破坏 key→分区 的稳定性。**

## 自检

1. 3 分区 Topic 最多能被同一个消费组的几个消费者并行消费？
2. 如果不给 key，消息会怎么分布？再跑一次步骤 3（去掉 `parse.key`）验证。
3. 为什么分区数"只能增不能减"？
