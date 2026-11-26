# RustFS 组件实验包

独立学习用，S3 API 在 `http://localhost:19000`，Console 在 `http://localhost:19001`。

## 1. 定位卡片

| 问题 | 回答 |
| --- | --- |
| 它是什么 | S3 兼容的**对象存储**：Bucket 里放 Object，通过 HTTP + SigV4 读写 |
| 解决什么 | 廉价可扩展的文件存放、存算分离、S3 生态兼容（Flink/Iceberg/备份工具直接对接） |
| 不解决什么 | 不是文件系统（没有真正的目录、不支持随机写）、不是表格式（不代表 Iceberg）、不做计算 |
| 和相邻组件的边界 | RustFS 只负责"按 key 存取字节"；schema、快照、查询由 Iceberg / Flink / StarRocks 负责 |

## 2. 核心抽象

| 概念 | 一句话理解 | 容易误解的点 |
| --- | --- | --- |
| Bucket | 顶层命名空间，类似"盘" | 名字全局风格、创建后不建议改名 |
| Object | Key + 内容 + 元数据 | 没有"目录"，`a/b/c.txt` 只是带斜杠的 key |
| ETag | 对象标识，通常是内容 MD5 | 分片上传时是 `md5-of-md5s-N`，**不等于文件 MD5** |
| Multipart | 大文件分片上传 | 分片后 ETag 变化；断点续传依赖它 |
| Presigned URL | 带签名的临时访问链接 | 签名包含 Host，换域名立即失效 |
| Path-style | `http://endpoint/bucket/key` | S3 SDK 默认可能是 virtual-host 风格，自建存储要显式开 path-style |
| Access Key | 凭证对（AK/SK） | 和云厂商的 AK 概念一致，但要自己保管 |

## 3. 快速开始

```bash
cd components/rustfs
docker compose up -d
docker compose ps          # rustfs-lab 应为 healthy

./scripts/mc.sh alias set lab http://rustfs:9000 rustfsadmin rustfsadmin
./scripts/mc.sh ls lab
```

- Console：<http://localhost:19001>，账号 `rustfsadmin / rustfsadmin`
- `mc` 运行在 `rustfs-mc` 容器里，用 `./scripts/mc.sh` 包装，避免本机安装客户端

## 4. 实验清单（按顺序做）

| 实验 | 主题 | 关键收获 |
| --- | --- | --- |
| [01](labs/01-start-connect.md) | 启动与连接 | Console、mc alias、集群状态 |
| [02](labs/02-bucket-object.md) | Bucket 与对象 | 上传/下载/删除、ETag 与 MD5、path-style |
| [03](labs/03-multipart.md) | 大文件与分片 | ETag 为什么会变成 `-N` 结尾 |
| [04](labs/04-presigned-url.md) | 预签名 URL | 临时授权、过期、Host 参与签名 |

每个实验固定写法：目标 → 命令 → **预期现象** → 破坏性实验 → 自检问题。

## 5. 排障清单

| 现象 | 优先检查 |
| --- | --- |
| 容器不 healthy | `docker logs rustfs-lab --tail 50`；端口 19000/19001 是否被占用 |
| `mc alias set` 失败 | 先确认 `rustfs-lab` healthy；endpoint 用容器内地址 `http://rustfs:9000` |
| 本机打不开预签名 URL | URL 里是 `rustfs:9000`，只在 compose 网络内可解析；在宿主机需换域名，但签名会失效 |
| 大文件 ETag 对不上 MD5 | 分片上传的正常现象，校验内容请比对实际 MD5 |
| SDK 报 region / checksum 错误 | 显式设置 region（如 `us-east-1`）、path-style，必要时关闭新版 checksum |
| 想清空数据 | `docker compose down -v`（会删除 bucket 与对象） |

## 6. 完成标准

能不看文档回答：

- Bucket、Object、Key 的关系是什么？为什么说没有目录？
- 单分片和分片上传的 ETag 有什么区别？
- 预签名 URL 为什么换个域名就打不开？
- 为什么自建对象存储常要求 path-style？
- Iceberg 的 Parquet 文件在这套体系里是"什么"？
