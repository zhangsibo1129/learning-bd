# 实验 04：脏数据与作业失败

**目标**：分清"被过滤"和"读取失败"，并学会从日志定位。

## 步骤

### 1. 故意把类型写错

`04-bad-schema.conf` 把 `name` 声明成 `int`，而数据是中文姓名。

```bash
./scripts/st.sh 04-bad-schema.conf; echo "exit=$?"
```

预期：`exit=1`，作业失败。

### 2. 找到真正的异常

```bash
./scripts/st.sh 04-bad-schema.conf 2>&1 | grep -E 'NumberFormatException|File read failed' | head -3
```

预期：

```
FileConnectorException: ErrorCode:[FILE-08] ... File read failed
Caused by: java.lang.NumberFormatException: For input string: "张伟"
```

### 3. 两种"失败"的区别

| 现象 | 含义 | 作业状态 |
| --- | --- | --- |
| Failed Count = 3，退出码 0 | 行被 WHERE 过滤，未进入 Sink | 成功 |
| 退出码 1，日志有 NumberFormatException | 读取阶段类型转换失败 | 失败，整批中止 |

所以不能只看统计数字，必须看退出码和异常。

### 4. 修复后重跑

```bash
mkdir -p jobs/local
sed 's/name = "int"/name = "string"/' jobs/04-bad-schema.conf \
  > jobs/local/04-fixed.conf

./scripts/st.sh local/04-fixed.conf 2>&1 | grep -E 'Total Read|Total Write|Total Failed'
```

预期：`Read = Write = 10, Failed = 0`。

## 破坏性实验：只坏一行

把 CSV 里某一行工资改成 `abc`（可复制到 `data/input/bad.csv`，并用 `sed` 改 path 指向它），再跑：

```bash
cp data/input/employees.csv data/input/bad.csv
sed -i '' '3s/12000/abc/' data/input/bad.csv    # macOS
mkdir -p jobs/local
sed 's#/data/input/employees.csv#/data/input/bad.csv#' jobs/04-bad-schema.conf \
  | sed 's/name = "int"/name = "string"/' > jobs/local/04-one-bad.conf
./scripts/st.sh local/04-one-bad.conf; echo "exit=$?"
```

预期：整批失败。

这正是生产里需要关注的点：**一行脏数据可能让整批同步失败**。常见治理方式是开启容错（跳过错误行并记录）或在入库前做质量校验。

## 自检

1. Failed Count 非零时，作业一定失败吗？
2. 读取阶段异常与写入阶段异常，处理方式有什么不同？
3. 生产上如何避免"一行坏数据拖垮整批"？
4. 为什么类型声明要和数据真实格式一致？
