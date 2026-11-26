# 实验 03：大文件与分片上传

**目标**：看清 multipart upload 对 ETag 的影响，避免把 ETag 当文件校验和。

## 步骤

### 1. 造一个 30 MiB 文件

```bash
docker exec rustfs-mc sh -c 'dd if=/dev/zero of=/tmp/big.bin bs=1M count=30 status=none'
docker exec rustfs-mc ls -lh /tmp/big.bin
```

### 2. 上传

```bash
./scripts/mc.sh cp /tmp/big.bin lab/demo/big.bin
```

预期：传输统计显示 30 MiB，速度通常很高（本地网络）。

### 3. 看 ETag

```bash
./scripts/mc.sh stat lab/demo/big.bin
```

预期：

```
Size      : 30 MiB
ETag      : 56313328e6aa42b57cd4d0bdeaac85f4-2
```

注意结尾的 **`-2`**：表示这个对象由 **2 个分片**组成（mc 默认分片 16 MiB）。

### 4. 校验内容完整性

ETag 已经不能再直接和本地 MD5 比较，要按实际内容校验：

```bash
docker exec rustfs-mc sh -c '
  echo "local  : $(md5sum /tmp/big.bin | cut -d" " -f1)"
  echo "remote : $(mc cat lab/demo/big.bin | md5sum | cut -d" " -f1)"
'
```

预期：两行完全一致。

### 5. 对照：小文件仍是单分片

```bash
docker exec rustfs-mc sh -c 'dd if=/dev/zero of=/tmp/small.bin bs=1M count=5 status=none'
./scripts/mc.sh cp /tmp/small.bin lab/demo/small.bin
./scripts/mc.sh stat lab/demo/small.bin | grep ETag
docker exec rustfs-mc sh -c 'md5sum /tmp/small.bin'
```

预期：5 MiB 文件 ETag **没有** `-N` 后缀，且等于 MD5。

## 关键结论

| 上传方式 | ETag 形式 | 能否当 MD5 用 |
| --- | --- | --- |
| 单分片 | 32 位十六进制 | 能 |
| 分片（multipart） | `md5-of-md5s-N` | **不能**，必须按内容重新计算 |

很多"上传后校验失败"的 bug，根源就是把 multipart 的 ETag 当成了文件 MD5。

## 破坏性实验：中断分片上传

上传到一半强制结束（在大文件传输时 `Ctrl+C`），然后看有没有残留：

```bash
./scripts/mc.sh ls --incomplete lab/demo
```

预期：能看到未完成的分片上传记录。这类残留会占用空间，需要生命周期规则或手动清理。

## 自检

1. 为什么 30 MiB 变成 2 个分片？
2. ETag 带 `-N` 时，怎么校验下载内容是否完整？
3. 中断的分片上传会留下什么？生产上怎么治理？
4. 分片大小越小越好吗？代价是什么？
