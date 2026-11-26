# SeaTunnel 组件实验包

独立学习用：本地模式（`-m local`）跑作业，数据放在 `data/`，不依赖外部服务。

## 1. 定位卡片

| 问题 | 回答 |
| --- | --- |
| 它是什么 | 数据集成引擎：用声明式配置描述 Source → Transform → Sink，负责"搬数据 + 轻量转换" |
| 解决什么 | 几百种数据源/目标之间的同步、字段映射、批量与实时接入、失败重试 |
| 不解决什么 | 不做复杂流计算（窗口、状态、CEP 交给 Flink）、不存数据、不做查询服务 |
| 和相邻组件的边界 | SeaTunnel 负责"进"和"出"；Kafka 负责缓冲与分发；Flink 负责重计算 |

## 2. 核心抽象

| 概念 | 一句话理解 | 容易误解的点 |
| --- | --- | --- |
| Job | 一份 HOCON 配置描述的数据流 | 配置写错时，作业可能在运行期才失败 |
| Source | 读数据的插件（File/JDBC/Kafka…） | 目录读取与并行度有坑，见排障 |
| Transform | 字段映射、SQL 过滤/计算 | 过滤掉的行会体现在 Failed Count 里 |
| Sink | 写数据的插件（Console/File/JDBC…） | 多 Sink 时必须用 `plugin_input` 显式接线 |
| Plugin | 每个 Connector 的 jar | 镜像里已内置常用连接器 |
| Checkpoint | 流式作业的容错机制 | 批量模式下不启用 |
| Parallelism | 每个插件的并行实例数 | 与文件数、分片策略强相关 |
| `plugin_output` | 给数据流注册一个"临时表名" | 多 Sink / 多 Transform 场景必须配置 |

## 3. 快速开始

```bash
cd components/seatunnel
docker compose up -d

./scripts/st.sh 01-fake-console.conf
```

`scripts/st.sh` 等价于在容器里执行：

```bash
./bin/seatunnel.sh --config /opt/seatunnel/jobs/<file> -m local
```

每次运行会启动一个内嵌集群（约 10～20 秒），作业结束后自动退出。

## 4. 实验清单（按顺序做）

| 实验 | 主题 | 关键收获 |
| --- | --- | --- |
| [01](labs/01-fake-console.md) | 第一个作业 | FakeSource → Console、作业统计 |
| [02](labs/02-file-transform.md) | 文件清洗 | CSV → SQL 过滤 → JSON、字段映射 |
| [03](labs/03-fanout.md) | 一份数据写两处 | `plugin_output` / `plugin_input` 接线 |
| [04](labs/04-bad-data.md) | 脏数据与失败 | 类型不匹配会让作业直接失败 |

每个实验固定写法：目标 → 命令 → **预期现象** → 破坏性实验 → 自检问题。

## 5. 排障清单

| 现象 | 优先检查 |
| --- | --- |
| 配置解析失败 | HOCON 注释用 `#` 或 `//`，不能用 `--`；字段值建议加引号 |
| 多 Sink 报 `plugin_output` 缺失 | Source 加 `plugin_output = "x"`，每个 Sink 加 `plugin_input = "x"` |
| Failed Count 非零但没报错 | 被 SQL `WHERE` 过滤掉的行也会计入，结合日志判断是不是脏数据 |
| 读目录时数据翻倍 | 2.3.9 实测：目录 + `parallelism > 1` 会重复分配文件，实验统一用 1 |
| 作业启动慢 | local 模式每次都要拉起内嵌集群，属正常 |
| 输出文件找不到 | 命名卷外看 `data/output/`，文件名形如 `T_<jobId>_<hash>_0_1_0.json` |
| 想清空输出 | `rm -rf data/output/*` |

## 6. 完成标准

能不看文档回答：

- Source / Transform / Sink 在配置里怎么连起来？
- 为什么多 Sink 时必须用 `plugin_output`？
- 过滤掉的数据为什么算进 Failed Count？
- SeaTunnel 和 Flink 的边界在哪里？
- 什么时候需要 checkpoint？
