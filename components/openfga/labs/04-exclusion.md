# 实验 04：排除关系（but not）

**目标**：用 `but not` 实现"有权限，但被拉黑就不行"。

## 模型

`model/04-exclusion.fga`：

```yaml
type user

type document
  relations
    define viewer: [user]
    define blocked: [user]
    define can_view: viewer but not blocked
```

`can_view` 的条件是：**是 viewer，且不是 blocked**。

## 步骤

### 1. 建 Store、写模型

```bash
STORE=$(./scripts/fga.sh store create --name lab04 2>/dev/null \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["store"]["id"])')

./scripts/fga.sh model write --store-id $STORE --file /model/04-exclusion.fga
```

### 2. 写事实

```bash
# alice、bob 都是 viewer
./scripts/fga.sh tuple write user:alice viewer document:doc1 --store-id $STORE
./scripts/fga.sh tuple write user:bob   viewer document:doc1 --store-id $STORE

# alice 被拉黑
./scripts/fga.sh tuple write user:alice blocked document:doc1 --store-id $STORE
```

### 3. 验证

```bash
./scripts/fga.sh query check user:alice can_view document:doc1 --store-id $STORE
./scripts/fga.sh query check user:bob   can_view document:doc1 --store-id $STORE
```

预期：alice `false`，bob `true`。

注意 alice 的 `viewer` 仍然是 true：

```bash
./scripts/fga.sh query check user:alice viewer document:doc1 --store-id $STORE
```

预期：`true`。**排除只作用于 `can_view`，不改变原始关系。**

## 破坏性实验：把 bob 也拉黑

```bash
./scripts/fga.sh tuple write user:bob blocked document:doc1 --store-id $STORE
./scripts/fga.sh query check user:bob can_view document:doc1 --store-id $STORE
```

预期：bob 也变 `false`。

## 关键结论

| 做法 | 效果 |
| --- | --- |
| 不写 viewer | 本来就没权限 |
| 写 viewer + blocked | 有权限但被显式拒绝 |
| 只靠删除 viewer | 表达不了"临时封禁、可恢复" |

`but not` 让"授权"和"阻断"可以独立管理，封禁到期只需删 blocked 这条 tuple。

## 自检

1. `viewer but not blocked` 与"直接不授权"有什么区别？
2. 如果一个人既是 blocked 又在另一个组里有权限，结果如何？
3. 为什么封禁适合用单独关系，而不是删除原授权？
4. 排除关系能否嵌套多层？
