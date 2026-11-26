#!/usr/bin/env bash
# 在 rustfs-mc 容器内执行 mc 命令
# 用法：./mc.sh alias set lab http://rustfs:9000 rustfsadmin rustfsadmin
#       ./mc.sh ls lab
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "用法: $0 <mc 参数...>"
  exit 1
fi

docker exec -i rustfs-mc mc "$@"
