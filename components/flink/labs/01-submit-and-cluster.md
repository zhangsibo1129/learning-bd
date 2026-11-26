# 实验 01：提交作业与集群结构

**目标**：跑通"提交 → 运行 → 观察 → 取消"，并看懂 Job / TaskManager / Slot。

## 步骤

### 1. 确认集群就绪

```bash
docker compose ps
./scripts/flink.sh flink list
```

预期：`flink-jm` 与 `flink-lab-taskmanager-1` 在运行；`flink list` 输出 `No running jobs.`

打开 <http://localhost:8081>，在 **Task Managers** 页应看到 1 个 TM、**2 个 Slot**。

### 2. 提交窗口作业

```bash
./scripts/flink.sh sql-client.sh -f /opt/flink/sql/02-window.sql
```

预期末尾输出：

```
[INFO] SQL update statement has been successfully submitted to the cluster:
Job ID: 14463befc8ffb1e621bda719d8cd5598
```

### 3. 查看作业状态

```bash
./scripts/flink.sh flink list
```

预期：`insert-into_default_catalog.default_database.window_sink (RUNNING)`。

UI 里点进作业，重点看三处：

- **Overview**：算子链、并行度、Checkpoint 状态；
- **Task Managers**：哪个 TM 在跑、用了几个 Slot；
- **Checkpoints**：本实验未开启，显示 `Disabled`。

### 4. 看结果输出

`print` sink 不打印到客户端，而是写进 TaskManager 日志：

```bash
docker logs flink-lab-taskmanager-1 2>&1 | grep -E '^\+I\[' | tail -5
```

预期（每 5 秒一个窗口）：

```
+I[2026-11-26T01:45:10, 2026-11-26T01:45:15, 3, 82.53...]
+I[2026-11-26T01:45:15, 2026-11-26T01:45:20, 9, 76.24...]
```

### 5. 取消作业

```bash
./scripts/flink.sh flink cancel <Job ID>
```

预期：`Cancelled job ...`，再 `flink list` 变为 `No running jobs.`

## 破坏性实验：并行度超过 Slot

把 `sql/02-window.sql` 里的 `parallelism.default` 改成 4 再提交（或直接用实验 04 的 SQL）：

```bash
./scripts/flink.sh sql-client.sh -f /opt/flink/sql/04-parallelism.sql
```

预期：`flink list` 显示 RUNNING，但 TM 日志没有任何 `+I[` 输出。

去 UI 看，算子状态是 `CREATED`、free slots 为 0——**"RUNNING 但不动"是资源不足的典型表现**，不是作业写错了。

## 自检

1. 提交成功但作业不跑，第一眼看哪里？
2. 并行度 1 的作业占几个 Slot？两个并行度 2 的算子能共用 Slot 吗？
3. `flink list` 的 RUNNING 和 UI 里算子 CREATED 矛盾吗？
4. JobManager 挂了，TaskManager 上的任务会怎样？
