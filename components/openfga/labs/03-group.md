# 实验 03：组与 ListObjects

**目标**：用"组"批量授权，并反查某人可编辑的对象列表。

## 模型

`model/03-group.fga`：

```yaml
type user

type group
  relations
    define member: [user]

type document
  relations
    define editor: [group#member]
    define owner: [user]
    define can_edit: editor or owner
```

`[group#member]` 表示：document 的 editor 可以是"某个组的成员"。

## 步骤

### 1. 建 Store、写模型

```bash
STORE=$(./scripts/fga.sh store create --name lab03 2>/dev/null \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["store"]["id"])')

./scripts/fga.sh model write --store-id $STORE --file /model/03-group.fga
```

### 2. 写组成员与文档授权

```bash
# alice 加入组 eng
./scripts/fga.sh tuple write user:alice member group:eng --store-id $STORE

# 组 eng 的成员都可以编辑 document spec
./scripts/fga.sh tuple write group:eng#member editor document:spec --store-id $STORE
```

### 3. 验证

```bash
./scripts/fga.sh query check user:alice can_edit document:spec --store-id $STORE
./scripts/fga.sh query check user:bob   can_edit document:spec --store-id $STORE
```

预期：alice `true`，bob `false`。

### 4. 反查对象列表

```bash
./scripts/fga.sh query list-objects --store-id $STORE user:alice can_edit document
```

预期：`{"objects":["document:spec"]}`。

注意参数是位置参数：**user、relation、type**，不是 `--type`。

## 破坏性实验：把 bob 拉进组

```bash
./scripts/fga.sh tuple write user:bob member group:eng --store-id $STORE

./scripts/fga.sh query check user:bob can_edit document:spec --store-id $STORE
./scripts/fga.sh query list-objects --store-id $STORE user:bob can_edit document
```

预期：bob 变 `true`，列表里也出现 `document:spec`。

再给 bob 单独一条 owner：

```bash
./scripts/fga.sh tuple write user:bob owner document:spec --store-id $STORE
```

`can_edit = editor or owner`，两条路径任一成立即可。

## 自检

1. `group#member` 和直接写 `user:alice` 有什么区别？
2. 用户离职时，删哪条 tuple 最省事？
3. ListObjects 适合用在什么接口上？
4. `or` 与 `and` 在权限模型里分别表达什么？
