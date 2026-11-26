# 实验 03：失败事件

**目标**：理解 FAIL 事件与 errorMessage facet，以及为什么失败也要上报。

## 步骤

### 1. 发送 START + FAIL

```bash
python3 emitters/03_fail.py
```

预期：

```
run_id = 957f1d78-...
START -> (201, '{"status": "ok"}')
FAIL  -> (201, '{"status": "ok"}')
```

### 2. 确认同一个 runId

```bash
tail -2 data/events.jsonl | python3 -c "
import json,sys
for line in sys.stdin:
    e=json.loads(line)['event']
    print(e['eventType'], e['run']['runId'])"
```

预期两行 `runId` 相同——START 和 FAIL 属于同一次执行。

### 3. 看错误 facet

```bash
tail -1 data/events.jsonl | python3 -c "
import json,sys
e=json.load(sys.stdin)['event']
print(json.dumps(e['run']['facets'], ensure_ascii=False, indent=2))"
```

预期：

```json
{
  "errorMessage": {
    "message": "java.lang.NumberFormatException: For input string: \"abc\"",
    "programmingLanguage": "JAVA"
  }
}
```

### 4. 血缘图里有没有这条失败运行

```bash
python3 emitters/04_summarize.py
```

失败运行不会增加数据集边（因为只统计 COMPLETE），但事件本身被保留，用于排障："这个输出表最后一次成功是什么时候？中间失败过几次？"

## 破坏性实验：只发 START 不发终态

把脚本里的 FAIL 注释掉（或直接手动只发 START）：

```bash
python3 - <<'PY'
import sys
sys.path.insert(0, "emitters")
from ol import dataset, event, new_run_id, post

run = new_run_id()
ev = event("START", run, "stuck_job", [dataset("postgres://demo", "raw_orders")])
print(post(ev))
PY
```

预期：事件被接收，但这条运行永远停在 START。

生产影响：血缘系统无法判断它是"还在跑"还是"进程崩了"，通常靠超时规则标记为孤儿运行。**终态事件（COMPLETE/FAIL/ABORT）必须发。**

## 自检

1. FAIL 事件应该带哪些信息？
2. 为什么同一个 runId 要贯穿 START 和 FAIL？
3. 只发 START 会带来什么问题？
4. 失败运行对下游血缘有什么价值？
