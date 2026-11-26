# 实验 04：并行度与 Slot

**目标**：理解并行度、Slot、TaskManager 的关系，以及"资源不足"的真实表现。

## 当前配置

- 1 个 TaskManager，`taskmanager.numberOfTaskSlots: 2`
- 作业并行度设为 4

## 步骤

### 0. 清空已有作业（关键）

上一个实验的作业会一直运行并占用 Slot。如果不清掉，新作业会因为拿不到资源直接进入 `RESTARTING`，而不是本实验要观察的"部分顶点 CREATED"。

```bash
# 列出并取消所有作业
./scripts/flink.sh flink list 2>/dev/null | grep -oE '[0-9a-f]{32}' \
  | xargs -I{} ./scripts/flink.sh flink cancel {}

# 确认没有残留
./scripts/flink.sh flink list 2>/dev/null | tail -3
```

预期最后只看到 `No running jobs.`。

### 1. 提交高并行度作业

确保只有一个 TM：

```bash
docker compose up -d --scale taskmanager=1
./scripts/flink.sh sql-client.sh -f /opt/flink/sql/04-parallelism.sql
```

记下 Job ID。

### 2. 观察异常状态

```bash
sleep 10
./scripts/flink.sh flink list
```

预期：作业可能显示 `RUNNING`（部分顶点 `CREATED`），也可能显示 `RESTARTING`（一个 Slot 都拿不到，反复重试）。两种都算正常，共同点是**没有新结果产出**：

```bash
# 只看最近 1 分钟，避免统计到上个实验的旧输出
docker logs flink-lab-taskmanager-1 --since 1m 2>&1 | grep -c '^\+I\['
```

预期：`0`。

用 REST 看细节：

```bash
curl -s http://localhost:8081/jobs/<Job ID> \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print([(v['name'],v['parallelism'],v['status']) for v in d['vertices']])"
```

预期：Source 顶点 `parallelism=4`、`status=CREATED`——有 subtask 拿不到 Slot，整个顶点起不来。

UI 上会显示 `Waiting for resources`。

### 3. 扩容 TaskManager

```bash
docker compose up -d --scale taskmanager=2
sleep 15
for c in flink-lab-taskmanager-1 flink-lab-taskmanager-2; do
  echo "== $c =="
  docker logs $c 2>&1 | grep -E '^\+I\[' | tail -2
done
```

预期：两个 TM 都开始输出窗口结果，作业变为真正 RUNNING。

### 4. 缩容观察

```bash
docker compose up -d --scale taskmanager=1
```

预期：作业先失败/重启，然后重新等待资源或按新 Slot 重新调度。这就是"扩容容易、缩容要小心"的原因。

## 概念对齐

| 概念 | 含义 | 本实验中的值 |
| --- | --- | --- |
| Slot | 一个 TM 能提供的并发执行单元 | 每 TM 2 个 |
| Parallelism | 每个算子的并行实例数 | 4 |
| 总 Slot | TM 数 × 每 TM Slot 数 | 1 台 = 2，2 台 = 4 |
| Slot 共享 | 不同算子的 subtask 可共用 Slot | 同一作业内默认开启 |

所以判断资源够不够，看的是 **最大算子并行度 ≤ 总 Slot 数**（开启 slot 共享时）。

## 自检

1. 并行度 4、总 Slot 2，为什么 `flink list` 仍显示 RUNNING？
2. 一个 Slot 能不能同时跑两个不同算子的 subtask？
3. 扩容 TM 后，已有状态会重新分布吗？代价是什么？
4. 为什么生产环境更常用"每 TM 固定 Slot + 动态扩 TM"，而不是随意调大并行度？
