# 实验 03：Checkpoint 与故障恢复

**目标**：亲手杀掉 TaskManager，确认作业从 Checkpoint 恢复，而不是从头重算。

## 步骤

### 1. 提交带 Checkpoint 的作业

```bash
./scripts/flink.sh sql-client.sh -f /opt/flink/sql/03-checkpoint.sql
```

记下输出的 Job ID。

### 2. 确认 Checkpoint 在写

```bash
sleep 15
ls savepoints/checkpoints/<Job ID>/
```

预期：出现 `chk-1`、`chk-2`… 目录。

UI 的 **Checkpoints** 页也能看到：`Completed` 数量增长、`Latest Restored` 为空。

### 3. 杀掉 TaskManager

```bash
docker compose kill taskmanager
sleep 8
./scripts/flink.sh flink list
```

预期：作业进入 `RESTARTING`（或短暂显示 RUNNING 后转 RESTARTING）。TM 没了，任务无处运行。

### 4. 把 TaskManager 拉起来

```bash
docker compose start taskmanager
sleep 20
./scripts/flink.sh flink list
```

预期：回到 `RUNNING`。

### 5. 确认是"恢复"而不是"重来"

```bash
docker logs flink-lab-taskmanager-1 2>&1 | grep -E "Restoring|restore from state" | tail -3
```

预期：

```
Starting to restore from state handle: KeyGroupsStateHandle{...}
Finished restoring from state handle: ...
```

UI 的 Checkpoints 页里 `Latest Restored` 会显示恢复所用的 checkpoint。

## 破坏性实验：把 Checkpoint 路径改到不可写

把 `03-checkpoint.sql` 中 checkpoint 目录改成 `file:///root/ckp`（容器内无权限），再提交：

```bash
mkdir -p sql/local
sed "s#file:///opt/flink/savepoints/checkpoints#file:///root/ckp#" \
  sql/03-checkpoint.sql > sql/local/03-checkpoint-bad.sql

./scripts/flink.sh sql-client.sh -f /opt/flink/sql/local/03-checkpoint-bad.sql
```

预期：作业运行但 Checkpoint 全部失败，UI 显示 `Failed`；杀掉 TM 后**无法恢复**，作业会一直重启直到失败次数上限。

这解释了线上最常见的一类问题：**作业能跑，但故障时恢复不了**。

## Checkpoint 与 Savepoint 的区别

| 维度 | Checkpoint | Savepoint |
| --- | --- | --- |
| 触发 | 框架周期性自动 | 用户手动 |
| 目的 | 故障自动恢复 | 升级、迁移、暂停后恢复 |
| 保留 | 通常只留最近几个 | 长期保留，自己管理 |
| 格式 | 内部格式，不保证兼容 | 标准化，跨版本恢复更稳 |

## 自检

1. 作业恢复后，窗口计数会从 0 开始吗？为什么？
2. Checkpoint 间隔越小越好吗？代价是什么？
3. Checkpoint 成功但 Savepoint 没做过，能升级 Flink 版本吗？
4. 为什么 Checkpoint 目录必须放在可靠存储上？
