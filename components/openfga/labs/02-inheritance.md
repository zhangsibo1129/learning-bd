# 实验 02：关系继承

**目标**：让 folder 的权限自动作用到里面的 document。

## 模型

`model/02-inheritance.fga`：

```yaml
type user

type folder
  relations
    define viewer: [user]

type document
  relations
    define parent: [folder]
    define viewer: [user] or viewer from parent
```

`viewer from parent` 表示：如果用户是父 folder 的 viewer，就自动成为 document 的 viewer。

## 步骤

### 1. 建 Store 并写模型

```bash
STORE=$(./scripts/fga.sh store create --name lab02 2>/dev/null \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["store"]["id"])')

./scripts/fga.sh model write --store-id $STORE --file /model/02-inheritance.fga
```

### 2. 写两条事实

```bash
# alice 是 folder eng 的 viewer
./scripts/fga.sh tuple write user:alice viewer folder:eng --store-id $STORE

# document roadmap 属于 folder eng（注意 user 位置放的是 folder）
./scripts/fga.sh tuple write folder:eng parent document:roadmap --store-id $STORE
```

### 3. 验证继承

```bash
./scripts/fga.sh query check user:alice viewer document:roadmap --store-id $STORE
./scripts/fga.sh query check user:bob   viewer document:roadmap --store-id $STORE
```

预期：alice `true`，bob `false`。

没有给 alice 写 `document:roadmap viewer`，权限是从 folder 推出来的。

## 破坏性实验：换一个人进 folder

```bash
./scripts/fga.sh tuple write user:bob viewer folder:eng --store-id $STORE

./scripts/fga.sh query check user:bob viewer document:roadmap --store-id $STORE
```

预期：bob 立刻变成 `true`——继承是**实时推导**的，不需要给每个 document 重复授权。

再检查一个不在 folder 里的用户：

```bash
./scripts/fga.sh query check user:carol viewer document:roadmap --store-id $STORE
```

预期：`false`。

## 自检

1. `viewer from parent` 中的 `parent` 是什么？
2. 如果 document 没有 `parent` tuple，继承会怎样？
3. 继承链能不能多层（folder → folder → document）？
4. 为什么这种设计比"给每个文档单独授权"更好维护？
