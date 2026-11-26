# 实验 02：文件清洗（CSV → 过滤 → JSON）

**目标**：走完 Source → SQL Transform → Sink，并读懂统计口径。

## 步骤

### 1. 输入数据

`data/input/employees.csv`：10 名员工，`salary` 有高有低。

### 2. 运行作业

```bash
./scripts/st.sh 02-file-to-file.conf
```

预期：

```
Total Read Count          :                  10
Total Write Count         :                   7
Total Failed Count        :                   3
```

### 3. 看输出文件

```bash
find data/output/high_salary -type f
head -5 data/output/high_salary/*.json
```

预期（文件名带 jobId，每次不同）：

```
{"id":1,"name":"张伟","city":"上海","salary":18000.0}
{"id":2,"name":"李娜","city":"北京","salary":12000.0}
{"id":3,"name":"王强","city":"深圳","salary":25000.0}
{"id":5,"name":"陈静","city":"成都","salary":15000.0}
{"id":7,"name":"赵敏","city":"北京","salary":22000.0}
```

只有 `salary >= 10000` 的 7 行被写出。

### 4. 为什么 Failed = 3

CSV 里有 3 人工资低于 10000，被 `WHERE salary >= 10000` 过滤掉。

SeaTunnel 把"读到了但没进入 Sink"的行计入 Failed Count。所以：

- **Failed > 0 不一定是脏数据**；
- 要结合日志和 Write Count 判断：`Read = Write + Failed` 通常说明是过滤，而不是异常。

### 5. 插件接线

```hocon
source  { LocalFile { plugin_output = "employees" ... } }
transform { Sql { plugin_input = "employees" plugin_output = "high_salary" ... } }
sink    { LocalFile { plugin_input = "high_salary" ... } }
```

`plugin_output` 给数据流注册临时表名，下游用 `plugin_input` 接上。链式配置靠这两个名字对齐。

## 破坏性实验：去掉过滤条件

```bash
mkdir -p jobs/local
sed 's/ where salary >= 10000//' jobs/02-file-to-file.conf \
  > jobs/local/02-all.conf

rm -rf data/output/high_salary
./scripts/st.sh local/02-all.conf 2>&1 | grep -E 'Total Read|Total Write|Total Failed'
```

预期：`Read = Write = 10, Failed = 0`。

## 自检

1. 没有 `plugin_input` 会怎样？
2. Failed Count 与真正的数据错误有什么区别？
3. 输出为什么是随机文件名？怎么固定？
4. 如果把 `file_format_type` 改成 `parquet`，下游消费方式会有什么变化？
