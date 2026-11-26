# OpenLineage 组件实验包

独立学习用：纯 Python（标准库）实现的**事件接收端 + 发送脚本**，用来观察血缘事件长什么样。

> OpenLineage 是**事件规范 + 客户端库**，本身没有服务端。服务端（存储、UI）是 Marquez 的职责，见 [components/marquez](../marquez)。

## 1. 定位卡片

| 问题 | 回答 |
| --- | --- |
| 它是什么 | 数据血缘的开放事件标准：用统一的 JSON 描述"哪个作业读了什么、写了什么、怎么映射字段" |
| 解决什么 | 不同引擎（Spark/Flink/Airflow/dbt）用同一种格式上报血缘，避免各家私有格式 |
| 不解决什么 | 不存血缘、不画图、不做权限；这些由 Marquez/DataHub/自建服务完成 |
| 和相邻组件的边界 | OpenLineage 只负责"说什么"；Marquez 负责"存和看"；OpenFGA 负责"谁能看" |

## 2. 核心抽象

| 概念 | 一句话理解 | 容易误解的点 |
| --- | --- | --- |
| Run | 一次作业执行，`runId` 唯一 | 同一次执行的所有事件共用一个 runId |
| Job | 作业定义，`namespace + name` | 不是调度任务本身，而是"干什么" |
| Dataset | 输入/输出数据集，`namespace + name` | 表、文件、主题都算 Dataset |
| Facet | 附加信息：schema、SQL、列级血缘、错误… | 可选，按需携带 |
| EventType | START / RUNNING / COMPLETE / FAIL / ABORT | FAIL 也要发，否则血缘"只进不出" |
| ColumnLineage | 输出字段 ← 输入字段的映射 | 字段名用 `field`，可多个来源 |
| Producer | 谁发的（agent/库的地址） | 用于排查数据来源 |

## 3. 快速开始

```bash
cd components/openlineage

# 终端 A：启动接收端（事件写入 data/events.jsonl）
python3 receiver/server.py

# 终端 B：发一条完整事件
python3 emitters/01_minimal.py
python3 emitters/04_summarize.py
```

- 接收端：`http://localhost:15000/api/v1/lineage`
- 事件文件：`data/events.jsonl`
- 无需安装任何第三方包，Python 3.8+ 即可

## 4. 实验清单（按顺序做）

| 实验 | 主题 | 关键收获 |
| --- | --- | --- |
| [01](labs/01-first-event.md) | 第一条事件 | Run/Job/Dataset/Facet 结构 |
| [02](labs/02-column-lineage.md) | 列级血缘 | 字段映射怎么表达 |
| [03](labs/03-fail-event.md) | 失败事件 | FAIL 与 errorMessage facet |
| [04](labs/04-rebuild-graph.md) | 从事件重建血缘图 | 节点、边、列映射的聚合 |

每个实验固定写法：目标 → 命令 → **预期现象** → 破坏性实验 → 自检问题。

## 5. 排障清单

| 现象 | 优先检查 |
| --- | --- |
| `HTTP Error 502` | 系统代理拦截了 localhost；`ol.py` 已对本机地址绕过代理，自写脚本需同样处理 |
| `Connection refused` | 接收端没启动，或端口不是 15000（`PORT=xxx python3 receiver/server.py`） |
| 事件文件为空 | 看终端 A 是否打印 `[receiver] START ...` |
| 中文乱码 | 事件以 `ensure_ascii=False` 写入，用支持 UTF-8 的编辑器查看 |
| 想清空重来 | `rm -rf data/`，接收端会自动重建 |
| 想接 Marquez | 把发送 URL 换成 `http://localhost:5000/api/v1/lineage`（Marquez 默认端口） |

## 6. 完成标准

能不看文档回答：

- START / COMPLETE / FAIL 三类事件分别携带什么？
- Facet 是可选的还是必须的？
- 列级血缘如何表示"一个输出字段来自两个输入字段"？
- 为什么血缘系统需要服务端，而 OpenLineage 不需要？
- 同一次运行的多条事件靠什么关联？
