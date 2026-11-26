# 实验 03：一份数据写两处（Sink 扇出）

**目标**：理解多 Sink 接线，以及 `plugin_output` 为什么必须有。

## 步骤

### 1. 运行作业

```bash
./scripts/st.sh 03-fanout.conf
```

预期统计：

```
Total Read Count          :                  10
Total Write Count         :                  10
Total Failed Count        :                   0
```

### 2. 两个目的地都有数据

- Console：日志里能看到 `rowIndex=` 的行；
- 文件：`data/output/fanout/` 下生成 JSON 文件。

```bash
./scripts/st.sh 03-fanout.conf 2>&1 | grep 'rowIndex=' | head -2
find data/output/fanout -type f
wc -l data/output/fanout/*.json
```

预期：每个文件 10 行（一次运行生成一个文件）。

### 3. 接线方式

```hocon
source {
  LocalFile {
    plugin_output = "employees"
    ...
  }
}

sink {
  Console { plugin_input = "employees" }
  LocalFile {
    plugin_input = "employees"
    path = "/data/output/fanout"
    ...
  }
}
```

同一份数据流被两个 Sink 同时消费。注意：**两个 Sink 各自写一份，不是二选一**。

## 破坏性实验：去掉 `plugin_output`

```bash
mkdir -p jobs/local
grep -v 'plugin_output' jobs/03-fanout.conf > jobs/local/03-no-output.conf
./scripts/st.sh local/03-no-output.conf 2>&1 | grep -A2 'JobDefineCheckException' | head -4
```

预期：

```
JobDefineCheckException: The source/transform(LocalFile) is not configured with 'plugin_output' option
```

原因：只有一个下游时，SeaTunnel 可以隐式接线；一旦有多个下游，就必须靠 `plugin_output` / `plugin_input` 显式命名数据流。

## 自检

1. 多 Sink 时，缺 `plugin_output` 为什么不行？
2. 两个 Sink 的数据是各写一份，还是负载均衡？
3. 如果其中一个 Sink 失败，另一个会怎样？
4. `plugin_input` 可以指向 Transform 的输出吗？
