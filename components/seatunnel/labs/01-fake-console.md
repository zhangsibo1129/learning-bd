# 实验 01：第一个作业

**目标**：跑通 FakeSource → Console，认识作业结构与统计。

## 步骤

### 1. 启动环境

```bash
docker compose up -d
docker compose ps
```

## 2. 运行作业

```bash
./scripts/st.sh 01-fake-console.conf
```

第一次启动会拉起内嵌集群，约 10～20 秒。

预期末尾：

```
Total Read Count          :                  10
Total Write Count         :                  10
Total Failed Count        :                   0
```

### 3. 看每一行

```bash
./scripts/st.sh 01-fake-console.conf 2>&1 | grep 'rowIndex=' | head -3
```

预期：

```
subtaskIndex=0  rowIndex=1:  SeaTunnelRow#tableId=default.default.default SeaTunnelRow#kind=INSERT : 4477018200211229696, zQXyC, 1.1550331999247008E308
```

三个字段对应配置里的 `id / name / score`，值是 FakeSource 随机生成的。

### 4. 配置结构

```hocon
env {
  parallelism = 1
  job.mode = "BATCH"
}
source  { FakeSource { row.num = 10 ... } }
sink    { Console {} }
```

- `job.mode = "BATCH"`：跑完就退出；
- `parallelism = 1`：一个并行实例；
- 没有 Transform 时，Source 直接接 Sink。

## 破坏性实验：把行数改成 100

```bash
mkdir -p jobs/local
sed 's/row.num = 10/row.num = 100/' jobs/01-fake-console.conf \
  > jobs/local/01-more.conf

./scripts/st.sh local/01-more.conf 2>&1 | grep -E 'Total Read|Total Write'
```

预期：Read/Write 都是 100。行数完全由配置决定，不涉及外部系统。

## 自检

1. 这个作业里 Transform 去哪了？
2. `job.mode` 改成 STREAMING 后，作业会自己退出吗？
3. `parallelism = 2` 时，每个并行实例都会生成 100 行吗？（试一下）
