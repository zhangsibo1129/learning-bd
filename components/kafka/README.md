# Kafka 组件实验包

独立学习用，不与其他组件串联。宿主机端口 `19092`，容器内为 `9092`。

## 1. 定位卡片

| 问题 | 回答 |
| --- | --- |
| 它是什么 | 分布式、可持久化的**事件日志**，按 Topic 追加写入，按 Offset 顺序读取 |
| 解决什么 | 系统间的异步解耦、削峰、多消费者各自按进度消费、事件可回放 |
| 不解决什么 | 不是数据库（不支持按条件查询）、不是任务队列（消费后消息不删除）、不做计算 |
| 和相邻组件的边界 | SeaTunnel/Flink 负责搬运与计算；Kafka 只负责"可靠地存一段时间 + 让人按顺序读" |

## 2. 核心抽象

| 概念 | 一句话理解 | 容易误解的点 |
| --- | --- | --- |
| Topic | 一类事件的逻辑名字 | 不是"队列"，可以被多个消费组重复读 |
| Partition | Topic 的物理分片，也是并行与顺序的单位 | 分区内有序，跨分区无序 |
| Offset | 消息在分区内的位置编号 | 由消费者保存进度，不是消息自带 ID |
| Consumer Group | 一组消费者共同消费一个 Topic，分区互斥分配 | 不同 group 互不影响，各自有 offset |
| Retention | 按时间/大小删除旧数据 | 消费与否不影响删除 |
| Compaction | 按 key 保留最新值 | 异步发生，不保证立刻生效 |

## 3. 快速开始

```bash
cd components/kafka
docker compose up -d
docker compose ps                 # 等待 healthy

./scripts/kafka.sh kafka-topics.sh \
  --bootstrap-server localhost:9092 --list
```

> 所有 Kafka 自带脚本都通过 `scripts/kafka.sh` 在容器内执行，避免本机安装 Kafka。

## 4. 实验清单（按顺序做）

| 实验 | 主题 | 关键收获 |
| --- | --- | --- |
| [01](labs/01-topic-and-partition.md) | Topic 与分区 | 分区数决定并行度；同 key 落同分区 |
| [02](labs/02-offset-and-group.md) | Offset 与消费组 | 消费进度由 group 保存；可重置、可重放 |
| [03](labs/03-rebalance.md) | 重平衡 | 消费者增减会触发分区重分配，期间有停顿 |
| [04](labs/04-retention.md) | 数据保留 | 数据按策略自动删除，与是否消费无关 |
| [05](labs/05-compaction.md) | 日志压缩 | 同 key 只留最新值，适合"状态快照"类数据 |

每个实验固定写法：目标 → 命令 → **预期现象** → 破坏性实验 → 自检问题。
做实验时把"实际输出"和"预期"不一致的地方记下来，那才是真正的学习点。

## 5. 排障清单

| 现象 | 优先检查 |
| --- | --- |
| 容器不 healthy | `docker logs kafka-lab --tail 50`，常见是 advertised listener 配错 |
| 客户端连不上 | `lsof -nP -iTCP:19092 -sTCP:LISTEN`；确认用的是 `localhost:19092` |
| 生产者超时 | 看 broker 日志是否在重连；单节点不要设置 `acks=all` + `min.insync.replicas>1` |
| 消费者没消息 | 同 group 已提交到末尾；换新 group 加 `--from-beginning` |
| Topic 建不出来 | `KAFKA_AUTO_CREATE_TOPICS_ENABLE=false`，必须显式建 Topic |
| 数据突然没了 | 检查 `retention.ms` 与 segment 是否已滚动 |

## 6. 重置环境

```bash
docker compose down          # 无数据卷，容器删除后数据清空
docker compose up -d
```

## 7. 完成标准

能不看文档回答：

- 为什么同一个 key 的消息总在同一个分区？
- 两个消费组读同一个 Topic，会不会互相抢消息？
- 消费者挂掉后，它没提交的 offset 会怎样？
- 为什么消息"消费过"还在磁盘上？
- compaction 和 retention 分别适合什么数据？
