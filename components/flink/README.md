# Flink 组件实验包

独立学习用：一个 JobManager + 可扩容的 TaskManager，UI 在 `http://localhost:8081`。

## 1. 定位卡片

| 问题 | 回答 |
| --- | --- |
| 它是什么 | 分布式**有状态流计算**引擎，按事件时间处理无界数据，也能跑批 |
| 解决什么 | 实时清洗/聚合/关联、窗口计算、故障后从 Checkpoint 恢复、精确一次语义 |
| 不解决什么 | 不是存储（不长期保存数据）、不是调度平台、不替代 Kafka |
| 和相邻组件的边界 | Kafka 负责存与传，Flink 负责算；算完写回 Kafka、Iceberg、JDBC 等外部系统 |

## 2. 核心抽象

| 概念 | 一句话理解 | 容易误解的点 |
| --- | --- | --- |
| Job | 一次提交的拓扑，由 Source → Transform → Sink 组成 | 作业提交成功 ≠ 正在运行，可能卡在资源不足 |
| JobManager | 管调度、Checkpoint 协调、REST/UI | 不是干活的进程 |
| TaskManager | 真正执行任务的进程，提供 Slot | 一个 TM 可以有多个 Slot |
| Slot | 资源单位，决定一个 TM 能并行跑多少 subtask | Slot 数 ≠ CPU 核数，是逻辑资源 |
| Parallelism | 每个算子的并行实例数 | 并行度 > 总 Slot 时会排队等待资源 |
| Operator Chain | 相邻算子合并成一个 task 减少网络开销 | 链不是越少越好，要看是否值得断开 |
| Watermark | 事件时间进度，用来触发窗口 | 它是"预计没有更早数据"的信号，不是真实时间 |
| State | 算子保存的中间结果 | 默认在内存/本地，故障后要靠 Checkpoint 恢复 |
| Checkpoint | 周期性状态快照，用于自动恢复 | 与 Savepoint 不同，生命周期由框架管理 |
| Savepoint | 手动触发的状态快照，用于升级/迁移 | 需要用户自己管理路径与恢复 |

## 3. 快速开始

```bash
cd components/flink
docker compose up -d

open http://localhost:8081        # Flink Web UI
./scripts/flink.sh flink list     # 通过容器内 CLI 查询作业
```

目录约定：

- `sql/`：可直接提交的 SQL 作业
- `savepoints/`：Checkpoint 与 Savepoint 落盘位置（宿主机可见）
- `scripts/flink.sh`：在 `flink-jm` 内执行 Flink 自带命令

## 4. 实验清单（按顺序做）

| 实验 | 主题 | 关键收获 |
| --- | --- | --- |
| [01](labs/01-submit-and-cluster.md) | 提交作业与集群结构 | Job/TM/Slot 的关系，UI 怎么看 |
| [02](labs/02-watermark-window.md) | Watermark 与窗口 | 窗口何时输出、迟到数据为何被丢 |
| [03](labs/03-checkpoint-recovery.md) | Checkpoint 与恢复 | 杀掉 TM 后作业如何续跑 |
| [04](labs/04-parallelism-slots.md) | 并行度与 Slot | 资源不足时作业"RUNNING 但不动" |

每个实验固定写法：目标 → 命令 → **预期现象** → 破坏性实验 → 自检问题。

> 实验之间记得先取消上一个作业，否则它会一直占用 Slot，导致下一个实验出现"资源不足"的假象。

## 5. 排障清单

| 现象 | 优先检查 |
| --- | --- |
| UI 打不开 | `docker compose ps` 看 `flink-jm`；`docker logs flink-jm --tail 50` |
| 作业一直 CREATED | Slot 不足：UI 的 Task Managers 页看 free slots，或调低并行度 |
| 作业 RESTARTING 循环 | 看 TM 日志里的异常；常见是 Checkpoint 路径不可写 |
| 看不到 print 输出 | print sink 打在 **TaskManager** 日志里：`docker logs flink-lab-taskmanager-1` |
| SQL Client 报连接失败 | 确认 JM 的 8081 已就绪；`./scripts/flink.sh flink list` 能通再提交 |
| Checkpoint 失败 | `savepoints/` 权限、磁盘空间；UI 的 Checkpoints 页看错误 |

## 6. 重置环境

```bash
docker compose down
rm -rf savepoints/*
docker compose up -d
```

## 7. 完成标准

能不看文档回答：

- JobManager 和 TaskManager 分别负责什么？
- 并行度 4、两个 Slot，会发生什么？
- Watermark 落后于事件时间，窗口会怎样？
- Checkpoint 和 Savepoint 的区别是什么？
- 为什么故障恢复后计数不会归零？
- 背压（backpressure）在 UI 的哪里看？
