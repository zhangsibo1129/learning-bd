#!/usr/bin/env bash
# 以一次性容器执行 fga 命令（CLI 镜像是 distroless，不常驻）
# 用法：./fga.sh store create --name demo
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "用法: $0 <fga 参数...>"
  exit 1
fi

cd "$(dirname "$0")/.."
docker compose --profile cli run --rm --no-deps -T cli "$@"
