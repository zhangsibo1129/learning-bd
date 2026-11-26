# OpenFGA 组件实验包

独立学习用：内存 datastore，HTTP API `18080`，Playground `13000`。

## 1. 定位卡片

| 问题 | 回答 |
| --- | --- |
| 它是什么 | 基于关系的授权引擎（ReBAC）：用"谁对什么有什么关系"判断能不能做某事 |
| 解决什么 | 对象级/行级/属性级权限、组织继承、共享与排除、集中式授权判定 |
| 不解决什么 | 不做身份认证（登录交给 IdP）、不存业务数据、不执行 Action 本身 |
| 和相邻组件的边界 | 业务系统问 OpenFGA "allowed?"；OpenFGA 只回答判定，不查业务库 |

## 2. 核心抽象

| 概念 | 一句话理解 | 容易误解的点 |
| --- | --- | --- |
| Store | 一个独立的授权空间 | 不同环境/租户用不同 Store |
| Authorization Model | 用 DSL 定义类型与关系 | 改模型会生成新版本，旧 tuple 仍按新模型解释 |
| Type | 对象类型，如 user/document/folder | 不是数据库表 |
| Relation | 关系，如 viewer/editor/owner | 可以是直接关系，也可以由其他关系推导 |
| Tuple | 一条事实：`user:alice viewer document:doc1` | 由"用户 关系 对象"三部分组成，CLI 顺序是 user 在前 |
| Check | 问"某人对某对象是否有某关系" | 只返回布尔值，不返回原因 |
| ListObjects | 问"某人能访问哪些对象" | 参数顺序是 user、relation、type |
| Contextual Tuple | 只在本次查询生效的临时事实 | 不落库，适合预览/测试 |

## 3. 快速开始

```bash
cd components/openfga
docker compose up -d          # 只启动 OpenFGA 服务

./scripts/fga.sh store create --name demo
open http://localhost:13000   # Playground，可视化模型与 tuple
```

CLI 镜像是 distroless（没有 shell），所以**不常驻**：`scripts/fga.sh` 每次用一次性容器执行 `fga`，命令结束即销毁。

## 4. 实验清单（按顺序做）

| 实验 | 主题 | 关键收获 |
| --- | --- | --- |
| [01](labs/01-store-model-tuple.md) | Store、模型、Tuple | 最小授权闭环 |
| [02](labs/02-inheritance.md) | 关系继承 | folder 权限自动传导到 document |
| [03](labs/03-group.md) | 组与 ListObjects | 组成员批量授权、反查对象列表 |
| [04](labs/04-exclusion.md) | 排除关系 | `but not` 实现黑名单 |

每个实验固定写法：目标 → 命令 → **预期现象** → 破坏性实验 → 自检问题。

## 5. 排障清单

| 现象 | 优先检查 |
| --- | --- |
| `exec: "/bin/sh": not found` | CLI 镜像没有 shell，不要常驻；用 `scripts/fga.sh` 一次性执行 |
| 连不上 API | 容器内地址是 `http://openfga:8080`（已设 `FGA_API_URL`），宿主机是 `18080` |
| `relation not found` | 检查 tuple 参数顺序：`fga tuple write <user> <relation> <object>` |
| `list-objects` 报错 | 是位置参数：`fga query list-objects --store-id X user:alice can_edit document` |
| 重启后 Store 消失 | datastore 是 memory；要持久化需切 Postgres/MySQL |
| 检查结果与预期不符 | 先 `fga tuple read --store-id X` 确认事实，再 `fga model get` 确认模型版本 |

## 6. 完成标准

能不看文档回答：

- Tuple、Relation、Model 三者的关系？
- 为什么 folder 的权限能作用到 document？
- Check 和 ListObjects 分别适合什么场景？
- `but not` 与"不写这条 tuple"有什么区别？
- 为什么授权判定不应该写在业务 SQL 里？
