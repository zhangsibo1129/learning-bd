# 实验 01：启动与连接

**目标**：把 RustFS 跑起来，用两种方式连上它。

## 步骤

### 1. 启动

```bash
docker compose up -d
docker compose ps
```

预期：`rustfs-lab` 状态为 `Up ... (healthy)`，端口映射 `19000->9000`、`19001->9001`。

### 2. 打开 Console

浏览器访问 <http://localhost:19001>，用下面的账号登录：

```
rustfsadmin / rustfsadmin
```

进去后能看到 Buckets 页面，目前是空的。

### 3. 用 mc 配置别名

`mc` 跑在 `rustfs-mc` 容器里，endpoint 用容器网络内的地址：

```bash
./scripts/mc.sh alias set lab http://rustfs:9000 rustfsadmin rustfsadmin
./scripts/mc.sh ls lab
```

预期：

```
Added `lab` successfully.
```

`mc ls lab` 此时没有输出（还没有 bucket）。

### 4. 看集群状态

```bash
./scripts/mc.sh admin info lab
```

预期：显示 Endpoint、Uptime、Version、Drives `1/1 OK`。

## 破坏性实验：用错误密码连接

```bash
./scripts/mc.sh alias set bad http://rustfs:9000 rustfsadmin wrong-password
./scripts/mc.sh ls bad
```

预期：返回 `Access Denied` 或签名错误。说明认证发生在 S3 请求层，而不是"连上就行"。

清理：

```bash
./scripts/mc.sh alias remove bad
```

## 自检

1. Console 端口和 S3 端口分别是哪个？
2. 为什么 mc 里用 `http://rustfs:9000` 而不是 `localhost:19000`？
3. AK/SK 泄露后，攻击者能做什么？
