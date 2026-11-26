# 实验 02：Bucket 与对象

**目标**：掌握对象存储最基本的四个动作：建桶、放、取、删，并理解 ETag 与 path-style。

## 步骤

### 1. 创建 Bucket

```bash
./scripts/mc.sh mb lab/demo
./scripts/mc.sh ls lab
```

预期：`Bucket created successfully 'lab/demo'.`，随后能看到 `demo/`。

### 2. 上传一个对象

在客户端容器里造一个文件，再上传：

```bash
docker exec rustfs-mc sh -c 'echo "hello rustfs" > /tmp/hello.txt'
./scripts/mc.sh cp /tmp/hello.txt lab/demo/hello.txt
```

预期：`/tmp/hello.txt -> lab/demo/hello.txt`，并打印传输统计。

### 3. 查看对象

```bash
./scripts/mc.sh ls lab/demo
./scripts/mc.sh stat lab/demo/hello.txt
./scripts/mc.sh cat lab/demo/hello.txt
```

预期：

```
[2026-11-26 ...]    13B STANDARD hello.txt
...
ETag      : e32ffcbee51903febddece70239591bb
...
hello rustfs
```

验证 ETag 就是内容 MD5：

```bash
docker exec rustfs-mc sh -c 'md5sum /tmp/hello.txt'
```

预期：与 ETag 完全一致。**单分片上传时 ETag = 文件 MD5**。

### 4. 下载并比对

```bash
./scripts/mc.sh cp lab/demo/hello.txt /tmp/hello-downloaded.txt
docker exec rustfs-mc sh -c '
  a=$(md5sum /tmp/hello.txt | cut -d" " -f1)
  b=$(md5sum /tmp/hello-downloaded.txt | cut -d" " -f1)
  [ "$a" = "$b" ] && echo identical
'
```

> 客户端镜像里没有 `diff`/`cmp`，用 MD5 比对即可。

### 5. 删除对象

```bash
./scripts/mc.sh rm lab/demo/hello.txt
./scripts/mc.sh ls lab/demo
```

预期：列表为空。

## 理解 path-style

mc 访问这个对象的实际 URL 是：

```
http://rustfs:9000/demo/hello.txt
```

Bucket（`demo`）在**路径**里，而不是域名里。这叫 path-style；云厂商默认常用 virtual-host 风格（`demo.s3.amazonaws.com/hello.txt`）。自建存储通常要求显式开启 path-style。

`hello.txt` 前面的"目录"并不存在，它只是 key 的一部分：

```bash
./scripts/mc.sh cp /tmp/hello.txt lab/demo/a/b/c/hello.txt
./scripts/mc.sh ls -r lab/demo
```

## 破坏性实验：同名覆盖

再上传一次同名文件、内容不同：

```bash
docker exec rustfs-mc sh -c 'echo "second version" > /tmp/hello.txt'
./scripts/mc.sh cp /tmp/hello.txt lab/demo/hello.txt
./scripts/mc.sh stat lab/demo/hello.txt | grep ETag
```

预期：ETag 变了，旧内容直接消失——**对象存储默认是不可变覆盖**。想保留历史，需要版本控制（RustFS 是否支持取决于版本与配置）。

## 自检

1. Object 的 "目录" 在存储层真的存在吗？
2. 为什么单分片上传的 ETag 等于 MD5？
3. 覆盖同名 key 后，旧数据还能找回吗？
4. path-style 和 virtual-host 风格差在哪？
