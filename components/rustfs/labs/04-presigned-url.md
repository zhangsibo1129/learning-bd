# 实验 04：预签名 URL

**目标**：理解"把私有对象临时分享出去"的机制，以及签名为什么会失效。

## 背景

私有 Bucket 默认只有带 AK/SK 的请求能访问。预签名 URL 的做法是：用 AK/SK 在本地算一个带签名的链接，任何人在有效期内都能直接用 HTTP 访问，**不需要凭证**。

## 步骤

### 1. 准备一个对象

```bash
docker exec rustfs-mc sh -c 'echo "hello rustfs" > /tmp/hello.txt'
./scripts/mc.sh cp /tmp/hello.txt lab/demo/presign.txt
```

### 2. 生成 10 秒有效的链接

```bash
./scripts/mc.sh share download --expire 10s lab/demo/presign.txt
```

预期输出：

```
URL: http://rustfs:9000/demo/presign.txt
Expire: 10 seconds
Share: http://rustfs:9000/demo/presign.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&
       X-Amz-Credential=...&X-Amz-Date=...&X-Amz-Expires=10&
       X-Amz-SignedHeaders=host&X-Amz-Signature=...
```

### 3. 立即用 curl 访问

链接里的主机名 `rustfs:9000` 只在 compose 网络内可解析，所以在 mc 容器里访问：

```bash
URL=$(./scripts/mc.sh share download --expire 10s lab/demo/presign.txt \
  | awk '/Share:/ {print $2}')

docker exec rustfs-mc sh -c "curl -fsS '$URL'"
```

预期：直接打印 `hello rustfs`，全程没有任何 Authorization 头。

### 4. 等过期后再访问

```bash
sleep 12
docker exec rustfs-mc sh -c "curl -s -o /dev/null -w 'status=%{http_code}\n' '$URL'"
```

预期：`status=403`，响应体通常含 `Request has expired`。

## 破坏性实验：把域名换掉

在宿主机上把 `rustfs:9000` 换成 `localhost:19000` 再访问：

```bash
# 先从容器里拿到原始 URL
URL=$(./scripts/mc.sh share download --expire 5m lab/demo/presign.txt \
  | awk '/Share:/ {print $2}')

curl -s -o /dev/null -w 'status=%{http_code}\n' \
  "${URL/rustfs:9000/localhost:19000}"
```

预期：`status=403`。

原因：SigV4 的签名内容里包含 **Host**（`X-Amz-SignedHeaders=host`）。换了域名，签名就对不上，即使 AK/SK 和有效期都没问题。

## 签名 URL 里各参数的含义

| 参数 | 含义 |
| --- | --- |
| `X-Amz-Algorithm` | 签名算法，这里是 AWS4-HMAC-SHA256 |
| `X-Amz-Credential` | AK + 日期 + region + 服务名 |
| `X-Amz-Date` | 签名生成时间 |
| `X-Amz-Expires` | 有效期（秒） |
| `X-Amz-SignedHeaders` | 参与签名的请求头，通常含 host |
| `X-Amz-Signature` | 最终签名值 |

## 自检

1. 预签名 URL 泄露后，风险窗口由什么决定？
2. 为什么把 `rustfs:9000` 改成 `localhost:19000` 会 403？
3. 预签名和"把 Bucket 设为公开"有什么区别？
4. 如果想让链接只能下载、不能上传，签名时要限制什么？
