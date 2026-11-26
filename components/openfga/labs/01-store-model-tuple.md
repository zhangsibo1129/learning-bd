# 实验 01：Store、模型与 Tuple

**目标**：完成最小授权闭环：建 Store → 写模型 → 写事实 → Check。

## 步骤

### 1. 启动并创建 Store

```bash
docker compose up -d
STORE=$(./scripts/fga.sh store create --name lab01 2>/dev/null \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["store"]["id"])')
echo $STORE
```

预期：打印形如 `01M8BB1BMSY5KZAVHXGS8ESM3B` 的 ID。

### 2. 写入模型

`model/01-basic.fga`：

```yaml
model
  schema 1.1

type user

type document
  relations
    define viewer: [user]
```

```bash
./scripts/fga.sh model write --store-id $STORE --file /model/01-basic.fga
```

预期：`{"authorization_model_id":"..."}`。

### 3. 先问一次（还没有任何授权）

```bash
./scripts/fga.sh query check user:alice viewer document:doc1 --store-id $STORE
```

预期：`{"allowed":false,"resolution":""}`。

### 4. 写入一条事实

```bash
./scripts/fga.sh tuple write user:alice viewer document:doc1 --store-id $STORE
```

注意参数顺序：**user → relation → object**。

预期：`{"successful":[{"object":"document:doc1","relation":"viewer","user":"user:alice"}]}`。

### 5. 再问一次

```bash
./scripts/fga.sh query check user:alice viewer document:doc1 --store-id $STORE
./scripts/fga.sh query check user:bob   viewer document:doc1 --store-id $STORE
```

预期：alice 为 `true`，bob 为 `false`。

### 6. 反查对象列表

```bash
./scripts/fga.sh query list-objects --store-id $STORE user:alice viewer document
```

预期：`{"objects":["document:doc1"]}`。

### 7. Playground

打开 <http://localhost:13000>，选择 Store，能看到模型、tuple，并直接点 Check。

## 破坏性实验：写一条模型里不存在的关系

```bash
./scripts/fga.sh tuple write user:alice admin document:doc1 --store-id $STORE
```

预期：`validation_error`，提示 `relation 'document#admin' not found`。

tuple 必须落在模型定义的关系上，不能随意发明。

## 自检

1. Store、Model、Tuple 各自的作用？
2. Check 返回 false，可能有哪些原因？
3. `list-objects` 与逐个 `check` 相比优势在哪？
